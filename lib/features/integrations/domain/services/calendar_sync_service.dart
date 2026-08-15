import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/data/repositories/event_repository.dart';
import 'package:bussola/features/integrations/data/repositories/integration_repository.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/repositories/remote_calendar_repository.dart';
import 'package:bussola/features/integrations/domain/services/remote_auth_service.dart';
import 'package:bussola/features/integrations/domain/services/sync_conflict_service.dart';

/// Orquestra a sincronização bidirecional e incremental entre o Bússola e
/// um calendário remoto. Não fala HTTP nem SQL diretamente — só coordena
/// [RemoteCalendarRepository] (a abstração — hoje só o Google a
/// implementa, via `GoogleCalendarRepository`), [EventRepository],
/// [IntegrationRepository] e [SyncConflictService], cada um responsável
/// por uma parte.
///
/// Generalizado: antes desta etapa, esta classe dependia diretamente de
/// `GoogleCalendarRepository`/`GoogleCalendarMapper` (tipos concretos do
/// Google), assumia sempre `CalendarProvider.googleCalendar` ao ler/gravar
/// o estado da integração, capturava a exceção específica do Google
/// (`GoogleTokenExpiredException`), dependia diretamente de
/// `GoogleAuthService` para autenticação, e tinha o Google como
/// valor-padrão silencioso de `remoteRepository`/`authService` quando não
/// injetados. Agora depende só de [RemoteCalendarRepository] e
/// [RemoteAuthService] — SEM nenhum valor-padrão para eles (são
/// obrigatórios): quem decide qual provedor usar é sempre quem constrói
/// o Service (hoje, `SyncGoogleCalendarUseCase`), nunca esta classe.
/// Recebe também o [CalendarProvider] como parâmetro de `syncNow`, e
/// captura só [RemoteCalendarAuthExpiredException] (erro de domínio,
/// neutro). A porta está pronta para uma futura implementação de Outlook
/// (ou qualquer outro provedor) sem precisar tocar em nenhuma linha desta
/// classe. O comportamento com o Google continua idêntico; só a
/// estrutura mudou.
///
/// Sequência oficial de uma sincronização (nesta ordem, sempre):
/// 1. Baixar as alterações do remoto (`listChangedEvents`, incremental via `syncToken`)
/// 2. Aplicar as alterações remoto → Bússola (criar/atualizar/soft-deletar localmente)
/// 3. Propagar exclusões locais → remoto
/// 4. Enviar criações/atualizações Bússola → remoto
/// 5. Salvar o novo `syncToken` — SÓ se os 4 passos acima terminaram sem erro
///
/// Estratégia de incrementalidade: usa o `syncToken` oficial do provedor
/// (guardado em `integrations.sync_token`) para só baixar o que mudou
/// desde a última vez — nunca baixa o calendário inteiro de novo, a não
/// ser na primeira sincronização ou se o provedor invalidar o token
/// (tratado pelo próprio Data Source de cada provedor).
class CalendarSyncService {
  final RemoteCalendarRepository _remoteRepository;
  final EventRepository _eventRepository;
  final IntegrationRepository _integrationRepository;
  final RemoteAuthService _authService;
  final SyncConflictService _conflictService;

  /// [remoteRepository] e [authService] são OBRIGATÓRIOS de propósito —
  /// são os dois únicos pontos desta classe que variam por provedor
  /// (Google, Outlook, ...). Antes da Etapa 1.3, ambos tinham um valor-
  /// padrão que caía silenciosamente para o Google quando omitidos — o
  /// que significava que, no dia em que existisse um segundo provedor,
  /// esquecer de passar um dos dois faria a sincronização usar o Google
  /// por engano, sem nenhum erro. Agora isso é impossível: quem monta um
  /// `CalendarSyncService` é obrigado a decidir explicitamente qual
  /// provedor está usando — essa decisão sai daqui e vai para quem
  /// instancia (hoje, só `SyncGoogleCalendarUseCase`).
  ///
  /// [eventRepository]/[integrationRepository]/[conflictService]
  /// continuam opcionais: não são específicos de nenhum provedor — são
  /// infraestrutura compartilhada (a mesma para Google, Outlook ou
  /// qualquer outro), então um valor-padrão aqui não esconde nenhuma
  /// decisão importante.
  CalendarSyncService({
    required RemoteCalendarRepository remoteRepository,
    required RemoteAuthService authService,
    EventRepository? eventRepository,
    IntegrationRepository? integrationRepository,
    SyncConflictService? conflictService,
  })  : _remoteRepository = remoteRepository,
        _eventRepository = eventRepository ?? EventRepository(),
        _integrationRepository = integrationRepository ?? IntegrationRepository(),
        _authService = authService,
        _conflictService = conflictService ?? SyncConflictService();

  Future<SyncResult> syncNow({
    required String userId,
    required String defaultCalendarId,
    required CalendarProvider provider,
    SyncDirection direction = SyncDirection.ambos,
  }) async {
    final accessToken = await _authService.getValidAccessToken(userId);
    if (accessToken == null) {
      throw StateError('Calendário remoto não está conectado ou o token expirou.');
    }

    try {
      return await _runSync(
        userId: userId,
        defaultCalendarId: defaultCalendarId,
        accessToken: accessToken,
        direction: direction,
        provider: provider,
      );
    } on RemoteCalendarAuthExpiredException {
      // 1ª tentativa: renovar o access_token (uma única vez — nunca em
      // loop) e repetir a MESMA operação que falhou.
      final renovacao = await _authService.refreshAccessToken(userId);

      if (renovacao.success) {
        final novoToken = await _authService.getValidAccessToken(userId);
        if (novoToken != null) {
          // Repete a sincronização do zero com o token novo. Isso é seguro
          // (não duplica nada) porque toda a lógica de criação/atualização
          // em `_runSync` já é idempotente por `googleEventId`/`id` — ver
          // auditoria de idempotência no relatório.
          try {
            return await _runSync(
              userId: userId,
              defaultCalendarId: defaultCalendarId,
              accessToken: novoToken,
              direction: direction,
              provider: provider,
            );
          } on RemoteCalendarAuthExpiredException {
            // Falhou de novo mesmo com o token renovado — não tenta
            // renovar uma segunda vez (evita loop). Marca erro e devolve
            // uma mensagem amigável, nunca a exceção técnica crua.
            await _integrationRepository.updateStatus(
              userId: userId,
              provider: provider,
              status: IntegrationStatus.erro,
            );
            throw StateError('Não foi possível concluir a sincronização agora. Tente novamente mais tarde.');
          }
        }
      }

      // Renovação falhou (refresh_token também inválido/revogado) — não
      // insiste de novo. Se a Edge Function já marcou como desconectado,
      // só propaga isso; senão, ainda assim marca aqui para não deixar a
      // integração num estado "conectado" mentiroso.
      if (renovacao.reconnectRequired) {
        await _integrationRepository.updateStatus(
          userId: userId,
          provider: provider,
          status: IntegrationStatus.desconectado,
        );
        throw const GoogleReconnectRequiredException('A autorização do calendário remoto expirou ou foi revogada. Reconecte sua conta.');
      }

      await _integrationRepository.updateStatus(
        userId: userId,
        provider: provider,
        status: IntegrationStatus.erro,
      );
      rethrow;
    }
  }

  Future<SyncResult> _runSync({
    required String userId,
    required String defaultCalendarId,
    required String accessToken,
    required CalendarProvider provider,
    SyncDirection direction = SyncDirection.ambos,
  }) async {
    final integration =
        await _integrationRepository.getIntegration(userId: userId, provider: provider);

    var criadosNoBussola = 0;
    var atualizados = 0;
    var excluidos = 0;
    var conflitos = 0;

    // ---------- 1-2. Baixar do Google e aplicar as alterações Google → Bússola ----------
    // A busca em si acontece sempre (é o que traz o `nextSyncToken`,
    // necessário mesmo numa sincronização "só exportar" para a próxima
    // continuar incremental) — só o PROCESSAMENTO dos eventos recebidos
    // é pulado quando a direção escolhida foi "apenas exportar".
    final pull = await _remoteRepository.listChangedEvents(accessToken: accessToken, syncToken: integration?.syncToken);

    if (direction != SyncDirection.apenasExportar) {
      for (final remoteEvent in pull.events) {
      final localCorrespondente =
          await _getLocalByExternalId(userId: userId, provider: provider, externalId: remoteEvent.externalId);

      if (remoteEvent.isCancelled) {
        if (localCorrespondente != null) {
          await _eventRepository.delete(localCorrespondente.id, deletedBy: userId);
          // Limpa o vínculo agora, não só quando o passo de exclusões rodar: o
          // evento já foi excluído por causa do PRÓPRIO remoto — não há
          // nada para "propagar de volta" a ele. Sem isso, o passo de exclusões
          // (exclusões locais → remoto) encontraria este mesmo evento já
          // soft-deletado com o vínculo ainda preenchido e tentaria
          // excluí-lo de novo no remoto, na mesma rodada.
          await _clearExternalId(localCorrespondente.id, provider);
          await _conflictService.logDeletedOneSide(
            userId: userId,
            provider: provider,
            eventId: localCorrespondente.id,
            googleEventId: remoteEvent.externalId,
            ladoQueExcluiu: provider.toDb(),
          );
          excluidos++;
        }
        continue;
      }

      if (localCorrespondente == null) {
        // Nunca visto antes — cria localmente.
        final novoModel = remoteEvent.toEventModel(userId: userId, calendarId: defaultCalendarId, provider: provider);
        await _eventRepository.create(novoModel);
        criadosNoBussola++;
        continue;
      }

      // Já existe dos dois lados — decidir se houve conflito.
      final ultimoSync = integration?.lastSyncAt;
      final localMudouDepoisDoSync = ultimoSync == null || localCorrespondente.updatedAt.isAfter(ultimoSync);
      final remotoMudouDepoisDoSync = ultimoSync == null || remoteEvent.updatedAt.isAfter(ultimoSync);

      if (localMudouDepoisDoSync && remotoMudouDepoisDoSync) {
        final vencedor = await _conflictService.resolveUpdatedBothSides(
          userId: userId,
          provider: provider,
          localEvent: localCorrespondente,
          remoteEvent: remoteEvent,
        );
        conflitos++;
        if (vencedor == ConflictWinner.remote) {
          final atualizado = remoteEvent.toEventModel(
            userId: userId,
            calendarId: defaultCalendarId,
            provider: provider,
            existingLocal: localCorrespondente,
          );
          await _eventRepository.update(atualizado);
          atualizados++;
        }
        // Se local venceu, o passo 4 (upload) abaixo já manda a versão local para o remoto.
      } else if (remotoMudouDepoisDoSync) {
        final atualizado = remoteEvent.toEventModel(
          userId: userId,
          calendarId: defaultCalendarId,
          provider: provider,
          existingLocal: localCorrespondente,
        );
        await _eventRepository.update(atualizado);
        atualizados++;
      }
    }
    } // fim do if (direction != SyncDirection.apenasExportar)

    // ---------- 3. Propagar exclusões locais → Google ----------
    // Ordem oficial da sincronização (passo 3 antes do passo 4). Nota:
    // como `getDeleted` e `getAllActive` são conjuntos disjuntos (um
    // evento nunca está nos dois ao mesmo tempo), essa ordem não evita
    // nenhum conflito entre exclusão e upload de um MESMO evento — é só
    // a sequência definida como contrato da sincronização.
    if (direction != SyncDirection.apenasImportar) {
      final excluidosLocalmente = await _eventRepository.getDeleted(userId);
      for (final evento in excluidosLocalmente) {
        final externalId = _externalIdFor(evento, provider);
        if (externalId != null) {
          await _remoteRepository.deleteEvent(accessToken: accessToken, externalEventId: externalId);
          // Limpa o vínculo — sem isso, toda sincronização futura tentaria
          // excluir de novo o mesmo evento (inofensivo, mas desnecessário).
          await _clearExternalId(evento.id, provider);
          excluidos++;
        }
      }
    }

    // ---------- 4. Enviar criações/atualizações Bússola → remoto ----------
    final ativos = await _eventRepository.getAllActive(userId);
    var criadosNoGoogle = 0;

    if (direction != SyncDirection.apenasImportar) {
      for (final evento in ativos) {
        final externalId = _externalIdFor(evento, provider);
        final agora = DateTime.now();
        if (externalId == null) {
          // Nunca foi enviado ao remoto — cria de lá.
          final criadoNoRemoto = await _remoteRepository.createEvent(accessToken: accessToken, event: evento);
          final comId = _comExternalId(evento, provider, criadoNoRemoto.externalId);
          await _eventRepository.update(_comSincronizacaoRegistrada(comId, provider, agora));
          criadosNoGoogle++;
        } else if (_lastSyncedAtFor(evento, provider) == null || _foiEditadoDeVerdadeDepoisDoSync(evento, provider)) {
          // Já existe no remoto, mas foi editado localmente depois da última sincronização COM ESTE provedor.
          await _remoteRepository.updateEvent(accessToken: accessToken, event: evento);
          await _eventRepository.update(_comSincronizacaoRegistrada(evento, provider, agora));
          atualizados++;
        }
      }
    }

    // ---------- 5. Salvar o novo syncToken — só se tudo acima terminou sem erro ----------
    await _integrationRepository.updateSyncState(
      userId: userId,
      provider: provider,
      syncToken: pull.nextSyncToken,
      lastSyncAt: DateTime.now(),
    );

    return SyncResult(
      criadosNoBussola: criadosNoBussola,
      criadosNoGoogle: criadosNoGoogle,
      atualizados: atualizados,
      excluidos: excluidos,
      conflitos: conflitos,
    );
  }

  /// Margem de tolerância entre `updated_at` (quando o CONTEÚDO do evento
  /// mudou de verdade — controlado pelo gatilho `set_updated_at` no banco,
  /// que roda no relógio do SERVIDOR) e `last_synced_at` (calculado no
  /// relógio do APP, alguns instantes antes de a escrita chegar ao banco).
  ///
  /// Sem essa margem, todo evento que acabou de ser puxado do Google e
  /// atualizado localmente (passo 1) pareceria "editado depois do sync"
  /// no passo 4 (upload) — só por causa da pequena diferença entre os dois
  /// relógios e a viagem de rede — e seria reenviado ao Google na MESMA
  /// rodada, sem necessidade nenhuma (não quebra nada, mas gasta uma
  /// chamada de API à toa e viola "uma sincronização sem mudanças não
  /// deve alterar nada"). Uma edição de verdade pela pessoa fica bem fora
  /// dessa janela de poucos segundos.
  ///
  /// LIMITAÇÃO RESOLVIDA (migration 0011): antes, `lastSyncedAt`/
  /// `syncOrigin` eram um único campo por evento — sincronizar um
  /// provedor "roubava" a marca de tempo do outro, fazendo o segundo
  /// provedor concluir, errado, que uma edição já tinha sido enviada
  /// para ele quando na verdade só foi enviada para o primeiro. Agora
  /// cada provedor lê/grava seu próprio campo
  /// (`googleLastSyncedAt`/`outlookLastSyncedAt`), então sincronizar
  /// Google nunca interfere no que o Outlook enxerga, e vice-versa.
  static const _margemRelogio = Duration(seconds: 5);

  bool _foiEditadoDeVerdadeDepoisDoSync(EventModel evento, CalendarProvider provider) {
    final ultimoSync = _lastSyncedAtFor(evento, provider);
    if (ultimoSync == null) return true;
    final diferenca = evento.updatedAt.difference(ultimoSync);
    return diferenca > _margemRelogio;
  }

  // ---------- Helpers provider-aware (correção pós-Etapa 1.15) ----------
  //
  // `EventModel` (feature agenda) não pode depender de `CalendarProvider`
  // (feature integrations) — inverteria a direção de dependência já
  // estabelecida em todo o projeto. Por isso esses helpers vivem aqui,
  // não como métodos de `EventModel`: são o único lugar que decide "qual
  // coluna usar" a partir do provider, e usam os métodos ESPELHADOS
  // (`getByGoogleEventId`/`getByOutlookEventId`, etc.) que já existem no
  // `EventRepository` — sem duplicar a lógica de busca/limpeza em si,
  // só decidindo qual das duas chamar.

  Future<EventModel?> _getLocalByExternalId({
    required String userId,
    required CalendarProvider provider,
    required String externalId,
  }) {
    switch (provider) {
      case CalendarProvider.googleCalendar:
        return _eventRepository.getByGoogleEventId(userId: userId, googleEventId: externalId);
      case CalendarProvider.outlook:
        return _eventRepository.getByOutlookEventId(userId: userId, outlookEventId: externalId);
      case CalendarProvider.appleCalendar:
        throw UnimplementedError('Apple Calendar ainda não suportado pela sincronização.');
    }
  }

  Future<void> _clearExternalId(String eventId, CalendarProvider provider) {
    switch (provider) {
      case CalendarProvider.googleCalendar:
        return _eventRepository.clearGoogleEventId(eventId);
      case CalendarProvider.outlook:
        return _eventRepository.clearOutlookEventId(eventId);
      case CalendarProvider.appleCalendar:
        throw UnimplementedError('Apple Calendar ainda não suportado pela sincronização.');
    }
  }

  /// ID externo (do provedor em questão) já vinculado a este evento, se
  /// houver — lê `googleEventId`/`outlookEventId` conforme [provider],
  /// nunca os dois misturados.
  String? _externalIdFor(EventModel evento, CalendarProvider provider) {
    switch (provider) {
      case CalendarProvider.googleCalendar:
        return evento.googleEventId;
      case CalendarProvider.outlook:
        return evento.outlookEventId;
      case CalendarProvider.appleCalendar:
        return null;
    }
  }

  /// `lastSyncedAt` do provedor em questão — migration 0011. Ler o campo
  /// ERRADO aqui (ex: sempre o antigo campo único) é exatamente o que
  /// causava a interferência entre Google e Outlook: o provedor que
  /// sincronizasse por último "roubava" a marca de tempo do outro.
  DateTime? _lastSyncedAtFor(EventModel evento, CalendarProvider provider) {
    switch (provider) {
      case CalendarProvider.googleCalendar:
        return evento.googleLastSyncedAt;
      case CalendarProvider.outlook:
        return evento.outlookLastSyncedAt;
      case CalendarProvider.appleCalendar:
        return null;
    }
  }

  /// Grava `lastSyncedAt`+`syncOrigin` só no campo do provedor em
  /// questão — o do OUTRO provedor fica intocado (é isso que elimina a
  /// interferência).
  EventModel _comSincronizacaoRegistrada(EventModel evento, CalendarProvider provider, DateTime agora) {
    switch (provider) {
      case CalendarProvider.googleCalendar:
        return evento.copyWith(googleLastSyncedAt: agora, googleSyncOrigin: SyncOrigin.synced);
      case CalendarProvider.outlook:
        return evento.copyWith(outlookLastSyncedAt: agora, outlookSyncOrigin: SyncOrigin.synced);
      case CalendarProvider.appleCalendar:
        return evento;
    }
  }

  /// Grava o ID recém-criado no remoto no campo certo — preserva o
  /// vínculo do OUTRO provedor (é isso que permite o mesmo evento local
  /// estar ligado a Google e Outlook ao mesmo tempo).
  EventModel _comExternalId(EventModel evento, CalendarProvider provider, String externalId) {
    switch (provider) {
      case CalendarProvider.googleCalendar:
        return evento.copyWith(googleEventId: externalId);
      case CalendarProvider.outlook:
        return evento.copyWith(outlookEventId: externalId);
      case CalendarProvider.appleCalendar:
        return evento;
    }
  }
}

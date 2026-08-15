import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';

/// Representa um evento vindo de um calendário remoto — Google, Outlook,
/// ou qualquer outro provedor futuro. O `CalendarSyncService` só conhece
/// este tipo; nunca o formato específico de nenhum provedor.
///
/// Esta classe nasce na generalização do `CalendarSyncService` como o
/// espelho genérico do que hoje é `GoogleCalendarEvent` — sem nada
/// específico de nenhum provedor no nome ou no tipo. Os campos de
/// recorrência (adicionados na Etapa 1.8) são anuláveis de propósito —
/// ver a documentação de [recurrenceType] abaixo.
class RemoteCalendarEvent {
  final String externalId;
  final String title;
  final String? description;
  final String? location;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String status; // valor cru do provedor (ex: Google manda "confirmed"/"cancelled") — use [isCancelled], não compare esta string diretamente
  final DateTime updatedAt; // última modificação no provedor remoto — usado para "última alteração vence"

  /// Recorrência mapeada pelo provedor — CAMPOS ANULÁVEIS DE PROPÓSITO.
  ///
  /// `null` em [recurrenceType] significa "este provedor não calcula/
  /// informa recorrência" (é o caso do Google hoje — `GoogleCalendarMapper`
  /// nunca preenche isso) — DIFERENTE de [RecurrenceType.nunca], que
  /// significa "o provedor confirma explicitamente que este evento não é
  /// recorrente" (ex: um evento comum do Outlook, sem campo `recurrence`).
  ///
  /// Essa distinção existe para o Outlook poder alimentar
  /// `EventModel.recurrenceType` de verdade sem quebrar o Google: em
  /// `toEventModel`, quando [recurrenceType] é `null`, o valor local
  /// já existente é preservado (exatamente o comportamento de antes desta
  /// etapa) — só quando um provedor de fato informa algo é que o valor
  /// muda.
  final RecurrenceType? recurrenceType;

  /// Texto livre com detalhe da recorrência — usado, por exemplo, para
  /// registrar POR QUE um padrão `personalizado` perdeu informação na
  /// conversão (ver `OutlookCalendarMapper.mapRecurrence`). Mesmo campo
  /// (`EventModel.recurrenceDetail`) que a UI já usa para recorrências
  /// personalizadas criadas localmente.
  final String? recurrenceDetail;
  final DateTime? recurrenceUntil;
  final int? recurrenceCount;

  const RemoteCalendarEvent({
    required this.externalId,
    required this.title,
    this.description,
    this.location,
    required this.start,
    required this.end,
    required this.allDay,
    required this.status,
    required this.updatedAt,
    this.recurrenceType,
    this.recurrenceDetail,
    this.recurrenceUntil,
    this.recurrenceCount,
  });

  /// Verdadeiro se o evento foi cancelado no provedor remoto.
  ///
  /// Existe para ninguém fora desta classe precisar comparar a string
  /// crua `status == 'cancelled'` — esse é o vocabulário específico do
  /// Google (a Microsoft Graph API, por exemplo, representa a mesma
  /// informação como um booleano `isCancelled`, não uma string). Antes
  /// desta etapa, essa comparação estava duplicada em dois lugares
  /// (aqui e no `CalendarSyncService`) — agora tem um único lugar que
  /// sabe traduzir o vocabulário do provedor para um conceito genérico.
  bool get isCancelled => status == 'cancelled';

  /// Constrói um [EventModel] pronto para criar/atualizar localmente a
  /// partir deste evento remoto — preenche `googleEventId`/`outlookEventId`
  /// e `googleLastSyncedAt`/`outlookLastSyncedAt`+`googleSyncOrigin`/
  /// `outlookSyncOrigin` (conforme [provider]).
  ///
  /// CORREÇÃO (pós-Etapa 1.15): antes, esta função sempre preenchia
  /// `googleEventId`/`syncOrigin: SyncOrigin.google`, mesmo quando o
  /// evento vinha do Outlook — bug real, corrigido com a migration
  /// `0010` (coluna `outlook_event_id` nova + `sync_origin` aceitando
  /// `'outlook'`) e a migration `0011` (campos de sincronização também
  /// separados por provedor, eliminando a interferência entre Google e
  /// Outlook). Agora [provider] decide quais campos popular, e sempre
  /// preserva os do OUTRO provedor a partir de [existingLocal].
  EventModel toEventModel({
    required String userId,
    required String calendarId,
    required CalendarProvider provider,
    EventModel? existingLocal,
  }) {
    final base = existingLocal;
    // Um único `now` para lastSyncedAt/updatedAt/createdAt — ver o motivo
    // (evita reenvio desnecessário ao remoto na mesma rodada) documentado
    // no `CalendarSyncService`.
    final agora = DateTime.now();
    final ehOutlook = provider == CalendarProvider.outlook;
    return EventModel(
      id: base?.id ?? '',
      calendarId: base?.calendarId ?? calendarId,
      userId: userId,
      title: title,
      description: description,
      startDatetime: start,
      endDatetime: end,
      timezone: base?.timezone ?? 'America/Sao_Paulo',
      allDay: allDay,
      location: location,
      categoryId: base?.categoryId,
      color: base?.color,
      priority: base?.priority ?? Priority.media,
      status: isCancelled ? EventStatus.cancelado : EventStatus.confirmado,
      // Fallback em cascata: usa o que o provedor informou; se o provedor
      // não informa nada (`null` — caso do Google hoje), preserva o valor
      // local já existente; só na ausência total dos dois é que assume
      // "nunca" — exatamente o comportamento de antes desta etapa para
      // quem não manda recorrência nenhuma.
      recurrenceType: recurrenceType ?? base?.recurrenceType ?? RecurrenceType.nunca,
      recurrenceDetail: recurrenceDetail ?? base?.recurrenceDetail,
      recurrenceUntil: recurrenceUntil ?? base?.recurrenceUntil,
      recurrenceCount: recurrenceCount ?? base?.recurrenceCount,
      createdBy: base?.createdBy ?? userId,
      updatedBy: userId,
      // Preserva o vínculo do OUTRO provedor, se existir — é exatamente
      // isso que permite o mesmo evento local ficar ligado a Google E
      // Outlook ao mesmo tempo, sem um sobrescrever o outro.
      googleEventId: ehOutlook ? base?.googleEventId : externalId,
      outlookEventId: ehOutlook ? externalId : base?.outlookEventId,
      // Campos antigos (compartilhados) — mantidos por compatibilidade,
      // não usados mais pela lógica de sincronização (ver `googleLastSyncedAt`/
      // `outlookLastSyncedAt` abaixo, migration 0011).
      lastSyncedAt: agora,
      syncOrigin: ehOutlook ? SyncOrigin.outlook : SyncOrigin.google,
      // Campos por provedor (migration 0011) — só o do provedor que
      // sincronizou agora muda; o do OUTRO provedor fica intocado
      // (preservado de `base`). É isso que elimina a interferência entre
      // Google e Outlook confirmada na auditoria.
      googleLastSyncedAt: ehOutlook ? base?.googleLastSyncedAt : agora,
      outlookLastSyncedAt: ehOutlook ? agora : base?.outlookLastSyncedAt,
      googleSyncOrigin: ehOutlook ? base?.googleSyncOrigin : SyncOrigin.google,
      outlookSyncOrigin: ehOutlook ? SyncOrigin.outlook : base?.outlookSyncOrigin,
      deletedAt: base?.deletedAt,
      createdAt: base?.createdAt ?? agora,
      updatedAt: agora,
    );
  }
}

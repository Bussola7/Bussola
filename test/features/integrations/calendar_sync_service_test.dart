import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/data/repositories/event_repository.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/domain/entities/remote_calendar_event.dart';
import 'package:bussola/features/integrations/domain/repositories/remote_calendar_repository.dart';
import 'package:bussola/features/integrations/data/repositories/integration_repository.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/services/calendar_sync_service.dart';
import 'package:bussola/features/integrations/domain/services/remote_auth_service.dart';
import 'package:bussola/features/integrations/domain/services/sync_conflict_service.dart';

const _userId = 'user-1';
const _calendarId = 'cal-1';

EventModel _buildLocal({
  required String id,
  String? googleEventId,
  String? outlookEventId,
  DateTime? updatedAt,
  DateTime? lastSyncedAt,
  DateTime? googleLastSyncedAt,
  DateTime? outlookLastSyncedAt,
  DateTime? deletedAt,
}) {
  final agora = DateTime(2026, 8, 1, 12);
  return EventModel(
    id: id,
    calendarId: _calendarId,
    userId: _userId,
    title: 'Evento $id',
    startDatetime: DateTime(2026, 8, 1, 9),
    endDatetime: DateTime(2026, 8, 1, 10),
    timezone: 'America/Sao_Paulo',
    allDay: false,
    googleEventId: googleEventId,
    outlookEventId: outlookEventId,
    lastSyncedAt: lastSyncedAt,
    googleLastSyncedAt: googleLastSyncedAt,
    outlookLastSyncedAt: outlookLastSyncedAt,
    deletedAt: deletedAt,
    createdAt: agora,
    updatedAt: updatedAt ?? agora,
  );
}

RemoteCalendarEvent _buildRemoteEvent({
  required String googleId,
  DateTime? updatedAt,
  String status = 'confirmed',
}) {
  return RemoteCalendarEvent(
    externalId: googleId,
    title: 'Evento remoto $googleId',
    start: DateTime(2026, 8, 1, 9),
    end: DateTime(2026, 8, 1, 10),
    allDay: false,
    status: status,
    updatedAt: updatedAt ?? DateTime(2026, 8, 1, 12),
  );
}

/// Repositório de eventos falso: mantém uma lista em memória — nenhuma
/// chamada toca no Supabase.
class _FakeEventRepository extends EventRepository {
  final List<EventModel> eventos;
  int proximoId = 1;
  int chamadasCreate = 0;
  int chamadasUpdate = 0;
  int chamadasDelete = 0;
  int? falharNaCriacaoDeNumero; // se definido, a N-ésima chamada a create() lança erro

  _FakeEventRepository([List<EventModel>? iniciais]) : eventos = iniciais ?? [];

  @override
  Future<EventModel?> getByGoogleEventId({required String userId, required String googleEventId}) async {
    for (final e in eventos) {
      if (e.googleEventId == googleEventId) return e;
    }
    return null;
  }

  @override
  Future<EventModel?> getByOutlookEventId({required String userId, required String outlookEventId}) async {
    for (final e in eventos) {
      if (e.outlookEventId == outlookEventId) return e;
    }
    return null;
  }

  @override
  Future<EventModel> create(EventModel event) async {
    chamadasCreate++;
    if (falharNaCriacaoDeNumero != null && chamadasCreate == falharNaCriacaoDeNumero) {
      throw Exception('falha simulada na criação #$chamadasCreate');
    }
    final novo = event.id.isEmpty ? _comNovoId(event, 'novo-${proximoId++}') : event;
    eventos.add(novo);
    return novo;
  }

  EventModel _comNovoId(EventModel event, String novoId) {
    return EventModel(
      id: novoId,
      calendarId: event.calendarId,
      userId: event.userId,
      title: event.title,
      description: event.description,
      startDatetime: event.startDatetime,
      endDatetime: event.endDatetime,
      timezone: event.timezone,
      allDay: event.allDay,
      location: event.location,
      categoryId: event.categoryId,
      priority: event.priority,
      status: event.status,
      googleEventId: event.googleEventId,
      outlookEventId: event.outlookEventId,
      lastSyncedAt: event.lastSyncedAt,
      syncOrigin: event.syncOrigin,
      googleLastSyncedAt: event.googleLastSyncedAt,
      outlookLastSyncedAt: event.outlookLastSyncedAt,
      googleSyncOrigin: event.googleSyncOrigin,
      outlookSyncOrigin: event.outlookSyncOrigin,
      createdAt: event.createdAt,
      updatedAt: event.updatedAt,
    );
  }

  @override
  Future<EventModel> update(EventModel event, {String? updatedByUserId}) async {
    chamadasUpdate++;
    final index = eventos.indexWhere((e) => e.id == event.id);
    if (index == -1) {
      eventos.add(event);
      return event;
    }
    eventos[index] = event;
    return event;
  }

  @override
  Future<void> delete(String id, {required String deletedBy}) async {
    chamadasDelete++;
    final index = eventos.indexWhere((e) => e.id == id);
    if (index != -1) {
      eventos[index] = eventos[index].copyWith(deletedAt: DateTime(2026, 8, 1, 13));
    }
  }

  @override
  Future<List<EventModel>> getAllActive(String userId) async => eventos.where((e) => !e.isDeleted).toList();

  @override
  Future<List<EventModel>> getDeleted(String userId) async => eventos.where((e) => e.isDeleted).toList();

  @override
  Future<void> clearGoogleEventId(String id) async {
    final index = eventos.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final atual = eventos[index];
    // Reconstrói sem o googleEventId (EventModel.copyWith não consegue
    // "zerar" um campo por causa do padrão `?? this.campo` — mesma
    // limitação já documentada e testada em outras etapas).
    eventos[index] = EventModel(
      id: atual.id,
      calendarId: atual.calendarId,
      userId: atual.userId,
      title: atual.title,
      startDatetime: atual.startDatetime,
      endDatetime: atual.endDatetime,
      timezone: atual.timezone,
      allDay: atual.allDay,
      outlookEventId: atual.outlookEventId, // preserva o vínculo do OUTRO provedor
      deletedAt: atual.deletedAt,
      lastSyncedAt: atual.lastSyncedAt,
      syncOrigin: atual.syncOrigin,
      googleLastSyncedAt: atual.googleLastSyncedAt,
      outlookLastSyncedAt: atual.outlookLastSyncedAt,
      googleSyncOrigin: atual.googleSyncOrigin,
      outlookSyncOrigin: atual.outlookSyncOrigin,
      createdAt: atual.createdAt,
      updatedAt: atual.updatedAt,
    );
  }

  @override
  Future<void> clearOutlookEventId(String id) async {
    final index = eventos.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final atual = eventos[index];
    eventos[index] = EventModel(
      id: atual.id,
      calendarId: atual.calendarId,
      userId: atual.userId,
      title: atual.title,
      startDatetime: atual.startDatetime,
      endDatetime: atual.endDatetime,
      timezone: atual.timezone,
      allDay: atual.allDay,
      googleEventId: atual.googleEventId, // preserva o vínculo do OUTRO provedor
      deletedAt: atual.deletedAt,
      lastSyncedAt: atual.lastSyncedAt,
      syncOrigin: atual.syncOrigin,
      googleLastSyncedAt: atual.googleLastSyncedAt,
      outlookLastSyncedAt: atual.outlookLastSyncedAt,
      googleSyncOrigin: atual.googleSyncOrigin,
      outlookSyncOrigin: atual.outlookSyncOrigin,
      createdAt: atual.createdAt,
      updatedAt: atual.updatedAt,
    );
  }
}

/// Repositório do Google falso: devolve uma lista configurada de eventos
/// "puxados" e simula criar/atualizar/excluir sem nenhuma chamada HTTP real.
class _FakeRemoteCalendarRepository implements RemoteCalendarRepository {
  List<RemoteCalendarEvent> eventosParaPuxar;
  String? proximoSyncToken;
  Object? erroAoListar;
  int chamadasListar = 0;
  int chamadasCreate = 0;
  int chamadasUpdate = 0;
  int chamadasDelete = 0;
  int proximoGoogleId = 1;
  final List<String>? log;

  _FakeRemoteCalendarRepository({this.eventosParaPuxar = const [], this.proximoSyncToken, this.log});

  @override
  Future<({List<RemoteCalendarEvent> events, String? nextSyncToken})> listChangedEvents({
    required String accessToken,
    String? syncToken,
  }) async {
    chamadasListar++;
    log?.add('download');
    if (erroAoListar != null) throw erroAoListar!;
    return (events: eventosParaPuxar, nextSyncToken: proximoSyncToken);
  }

  @override
  Future<RemoteCalendarEvent> createEvent({required String accessToken, required EventModel event}) async {
    chamadasCreate++;
    log?.add('upload_local');
    return _buildRemoteEvent(googleId: 'google-novo-${proximoGoogleId++}');
  }

  @override
  Future<RemoteCalendarEvent> updateEvent({required String accessToken, required EventModel event}) async {
    chamadasUpdate++;
    log?.add('upload_local');
    return _buildRemoteEvent(googleId: event.googleEventId!);
  }

  @override
  Future<void> deleteEvent({required String accessToken, required String externalEventId}) async {
    chamadasDelete++;
    log?.add('delete_local_to_google');
  }
}

class _FakeIntegrationRepository extends IntegrationRepository {
  CalendarIntegrationModel? integracao;
  int chamadasUpdateSyncState = 0;
  int chamadasUpdateStatus = 0;
  String? ultimoSyncTokenSalvo;
  IntegrationStatus? ultimoStatus;
  CalendarProvider? ultimoProviderRecebido;
  final List<String>? log;

  _FakeIntegrationRepository(this.integracao, {this.log});

  @override
  Future<CalendarIntegrationModel?> getIntegration({required String userId, required CalendarProvider provider}) async {
    ultimoProviderRecebido = provider;
    return integracao;
  }

  @override
  Future<void> updateSyncState({
    required String userId,
    required CalendarProvider provider,
    String? syncToken,
    required DateTime lastSyncAt,
  }) async {
    chamadasUpdateSyncState++;
    ultimoSyncTokenSalvo = syncToken;
    ultimoProviderRecebido = provider;
    log?.add('save_token');
  }

  @override
  Future<void> updateStatus({required String userId, required CalendarProvider provider, required IntegrationStatus status}) async {
    chamadasUpdateStatus++;
    ultimoStatus = status;
    ultimoProviderRecebido = provider;
  }
}

/// Fake que implementa a INTERFACE ([RemoteAuthService]), não o tipo
/// concreto do Google — é isto que prova, estruturalmente, que o
/// `CalendarSyncService` não depende de `GoogleAuthService` (se
/// dependesse, este fake nem compilaria).
class _FakeGoogleAuthService implements RemoteAuthService {
  final List<String?> tokens;
  int chamadasGetToken = 0;
  RefreshResult refreshResultado;
  int chamadasRefresh = 0;

  _FakeGoogleAuthService({
    required this.tokens,
    this.refreshResultado = const RefreshResult(success: false, reconnectRequired: false),
  });

  @override
  Future<String?> getValidAccessToken(String userId) async {
    final indice = chamadasGetToken.clamp(0, tokens.length - 1);
    chamadasGetToken++;
    return tokens[indice];
  }

  @override
  Future<RefreshResult> refreshAccessToken(String userId) async {
    chamadasRefresh++;
    return refreshResultado;
  }
}

class _FakeSyncConflictService extends SyncConflictService {
  ConflictWinner vencedorConfigurado;
  int chamadasResolveUpdated = 0;
  int chamadasLogDeleted = 0;
  String? ultimoLadoQueExcluiu;

  _FakeSyncConflictService({this.vencedorConfigurado = ConflictWinner.local});

  @override
  Future<ConflictWinner> resolveUpdatedBothSides({
    required String userId,
    required CalendarProvider provider,
    required EventModel localEvent,
    required RemoteCalendarEvent remoteEvent,
  }) async {
    chamadasResolveUpdated++;
    return vencedorConfigurado;
  }

  @override
  Future<void> logDeletedOneSide({
    required String userId,
    required CalendarProvider provider,
    String? eventId,
    String? googleEventId,
    required String ladoQueExcluiu,
  }) async {
    chamadasLogDeleted++;
    ultimoLadoQueExcluiu = ladoQueExcluiu;
  }
}

CalendarSyncService _buildService({
  required _FakeEventRepository eventRepo,
  required _FakeRemoteCalendarRepository googleRepo,
  required _FakeIntegrationRepository integrationRepo,
  required _FakeGoogleAuthService authService,
  _FakeSyncConflictService? conflictService,
}) {
  return CalendarSyncService(
    eventRepository: eventRepo,
    remoteRepository: googleRepo,
    integrationRepository: integrationRepo,
    authService: authService,
    conflictService: conflictService ?? _FakeSyncConflictService(),
  );
}

void main() {
  group('CalendarSyncService — criação', () {
    test('Google → Bússola: evento novo do Google vira evento local novo', () async {
      final eventRepo = _FakeEventRepository();
      final googleRepo = _FakeRemoteCalendarRepository(eventosParaPuxar: [_buildRemoteEvent(googleId: 'g-1')]);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(resultado.criadosNoBussola, 1);
      expect(eventRepo.eventos.length, 1);
      expect(eventRepo.eventos.first.googleEventId, 'g-1');
    });

    test('Bússola → Google: evento local sem googleEventId é criado no Google', () async {
      final eventRepo = _FakeEventRepository([_buildLocal(id: 'local-1')]);
      final googleRepo = _FakeRemoteCalendarRepository();
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(resultado.criadosNoGoogle, 1);
      expect(googleRepo.chamadasCreate, 1);
      expect(eventRepo.eventos.first.googleEventId, isNotNull);
    });
  });

  group('CalendarSyncService — atualização', () {
    test('Google → Bússola: evento do Google mais novo atualiza o local', () async {
      final local = _buildLocal(
        id: 'local-1', googleEventId: 'g-1', updatedAt: DateTime(2026, 1, 1), lastSyncedAt: DateTime(2026, 1, 1));
      final eventRepo = _FakeEventRepository([local]);
      final integracao = CalendarIntegrationModel(
        id: 'int-1', userId: _userId, provider: CalendarProvider.googleCalendar,
        status: IntegrationStatus.conectado, lastSyncAt: DateTime(2026, 1, 2), updatedAt: DateTime(2026, 1, 2),
      );
      final googleRepo = _FakeRemoteCalendarRepository(
        eventosParaPuxar: [_buildRemoteEvent(googleId: 'g-1', updatedAt: DateTime(2026, 8, 1))],
      );
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(integracao),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(resultado.atualizados, 1);
      expect(eventRepo.chamadasUpdate, 1);
    });

    test('Bússola → Google: evento local editado depois do último sync é enviado', () async {
      final local = _buildLocal(
        id: 'local-1',
        googleEventId: 'g-1',
        googleLastSyncedAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 8, 1),
      );
      final eventRepo = _FakeEventRepository([local]);
      final googleRepo = _FakeRemoteCalendarRepository();
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(resultado.atualizados, 1);
      expect(googleRepo.chamadasUpdate, 1);
    });
  });

  group('CalendarSyncService — exclusão', () {
    test('Google → Bússola: evento cancelado no Google faz soft delete local, limpa o vínculo e NÃO tenta excluir de novo no Google', () async {
      final local = _buildLocal(id: 'local-1', googleEventId: 'g-1');
      final eventRepo = _FakeEventRepository([local]);
      final googleRepo = _FakeRemoteCalendarRepository(
        eventosParaPuxar: [_buildRemoteEvent(googleId: 'g-1', status: 'cancelled')],
      );
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(resultado.excluidos, 1); // só 1, não 2 — é a correção desta etapa
      expect(eventRepo.eventos.first.isDeleted, true);
      expect(eventRepo.eventos.first.googleEventId, isNull);
      // O Google foi quem cancelou — não faz sentido o passo "local → Google"
      // tentar excluir esse mesmo evento no Google de novo, na mesma rodada.
      expect(googleRepo.chamadasDelete, 0);
    });

    test('REGRESSÃO (auditoria pós-1.15): ladoQueExcluiu reflete o provider REAL, não sempre "google"', () async {
      // Bug real encontrado: o valor era sempre a string fixa 'google',
      // mesmo quando o provider de verdade era outlook — o log de
      // auditoria mentia sobre qual provedor causou a exclusão.
      final localGoogle = _buildLocal(id: 'local-1', googleEventId: 'g-1');
      final eventRepoGoogle = _FakeEventRepository([localGoogle]);
      final googleRepo = _FakeRemoteCalendarRepository(
        eventosParaPuxar: [_buildRemoteEvent(googleId: 'g-1', status: 'cancelled')],
      );
      final conflictServiceGoogle = _FakeSyncConflictService();
      final serviceGoogle = _buildService(
        eventRepo: eventRepoGoogle,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
        conflictService: conflictServiceGoogle,
      );

      await serviceGoogle.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(conflictServiceGoogle.ultimoLadoQueExcluiu, 'google_calendar');

      // Mesmo cenário, mas com provider = outlook — o valor gravado
      // precisa mudar de acordo, não continuar fixo em "google".
      final localOutlook = _buildLocal(id: 'local-2', googleEventId: 'o-1');
      final eventRepoOutlook = _FakeEventRepository([localOutlook]);
      final outlookRepo = _FakeRemoteCalendarRepository(
        eventosParaPuxar: [_buildRemoteEvent(googleId: 'o-1', status: 'cancelled')],
      );
      final conflictServiceOutlook = _FakeSyncConflictService();
      final serviceOutlook = _buildService(
        eventRepo: eventRepoOutlook,
        googleRepo: outlookRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
        conflictService: conflictServiceOutlook,
      );

      await serviceOutlook.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.outlook);

      expect(conflictServiceOutlook.ultimoLadoQueExcluiu, 'outlook');
    });

    test('Bússola → Google: evento excluído localmente é excluído no Google e o vínculo é limpo', () async {
      final local = _buildLocal(id: 'local-1', googleEventId: 'g-1', deletedAt: DateTime(2026, 8, 1));
      final eventRepo = _FakeEventRepository([local]);
      final googleRepo = _FakeRemoteCalendarRepository();
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(resultado.excluidos, 1);
      expect(googleRepo.chamadasDelete, 1);
      expect(eventRepo.eventos.first.googleEventId, isNull);
    });
  });

  group('CalendarSyncService — idempotência', () {
    test('sincronizar 2x seguidas sem nenhuma mudança externa não cria/atualiza/exclui nada na 2ª vez', () async {
      final local = _buildLocal(id: 'local-1', googleEventId: 'g-1', googleLastSyncedAt: DateTime(2026, 8, 1, 12));
      final eventRepo = _FakeEventRepository([local]);
      final googleRepo = _FakeRemoteCalendarRepository();
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1', 'token-1']),
      );

      final primeira = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);
      final segunda = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(primeira.criadosNoBussola + primeira.criadosNoGoogle, 0);
      expect(segunda.criadosNoBussola + segunda.criadosNoGoogle, 0);
      expect(segunda.atualizados, 0);
      expect(segunda.excluidos, 0);
    });

    test('exclusão já propagada ao Google não é repetida numa segunda sincronização', () async {
      final localExcluido = _buildLocal(id: 'local-1', googleEventId: 'g-1', deletedAt: DateTime(2026, 8, 1));
      final eventRepo = _FakeEventRepository([localExcluido]);
      final googleRepo = _FakeRemoteCalendarRepository();
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1', 'token-1']),
      );

      await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);
      expect(googleRepo.chamadasDelete, 1);

      await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);
      expect(googleRepo.chamadasDelete, 1);
    });
  });

  group('CalendarSyncService — conflitos', () {
    test('local e Google mudaram depois do último sync: conta como conflito e aplica o vencedor', () async {
      final local = _buildLocal(id: 'local-1', googleEventId: 'g-1', updatedAt: DateTime(2026, 8, 1, 15));
      final eventRepo = _FakeEventRepository([local]);
      final integracao = CalendarIntegrationModel(
        id: 'int-1', userId: _userId, provider: CalendarProvider.googleCalendar,
        status: IntegrationStatus.conectado, lastSyncAt: DateTime(2026, 8, 1, 10), updatedAt: DateTime(2026, 8, 1, 10),
      );
      final googleRepo = _FakeRemoteCalendarRepository(
        eventosParaPuxar: [_buildRemoteEvent(googleId: 'g-1', updatedAt: DateTime(2026, 8, 1, 14))],
      );
      final conflictService = _FakeSyncConflictService(vencedorConfigurado: ConflictWinner.remote);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(integracao),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
        conflictService: conflictService,
      );

      final resultado = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(resultado.conflitos, 1);
      expect(conflictService.chamadasResolveUpdated, 1);
      expect(resultado.atualizados, 1);
    });
  });

  group('CalendarSyncService — reconnect / refresh token', () {
    test('refresh token inválido/revogado: marca desconectado e lança GoogleReconnectRequiredException, sem loop', () async {
      final eventRepo = _FakeEventRepository();
      final googleRepo = _FakeRemoteCalendarRepository()..erroAoListar = RemoteCalendarAuthExpiredException('token expirado (teste)');
      final authService = _FakeGoogleAuthService(
        tokens: ['token-expirado'],
        refreshResultado: const RefreshResult(success: false, reconnectRequired: true),
      );
      final integrationRepo = _FakeIntegrationRepository(null);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: integrationRepo,
        authService: authService,
      );

      await expectLater(
        service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar),
        throwsA(isA<GoogleReconnectRequiredException>()),
      );

      expect(authService.chamadasRefresh, 1);
      expect(integrationRepo.ultimoStatus, IntegrationStatus.desconectado);
    });

    test('token expirado mas renovação bem-sucedida: repete a sincronização com o novo token', () async {
      final eventRepo = _FakeEventRepository();
      final googleRepo = _FakeRemoteCalendarRepository()..erroAoListar = RemoteCalendarAuthExpiredException('token expirado (teste)');
      final authService = _FakeGoogleAuthService(
        tokens: ['token-expirado', 'token-novo'],
        refreshResultado: const RefreshResult(success: true, reconnectRequired: false),
      );
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: authService,
      );

      // A 1ª chamada a listChangedEvents sempre vai lançar (erroAoListar
      // fica configurado durante toda a execução do fake) — então mesmo
      // após renovar, a 2ª tentativa também lança RemoteCalendarAuthExpiredException
      // de novo, e o Service NÃO tenta renovar uma segunda vez.
      await expectLater(
        service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar),
        throwsA(isA<StateError>()),
      );

      expect(authService.chamadasRefresh, 1); // só uma tentativa de renovação, nunca loop
      expect(googleRepo.chamadasListar, 2); // tentativa original + a repetição após renovar
    });
  });

  group('CalendarSyncService — falha não corrompe estado local', () {
    test('erro genérico na listagem propaga sem salvar syncToken (permite retry seguro na próxima vez)', () async {
      final eventRepo = _FakeEventRepository();
      final googleRepo = _FakeRemoteCalendarRepository()..erroAoListar = Exception('falha de rede genérica');
      final integrationRepo = _FakeIntegrationRepository(null);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: integrationRepo,
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      await expectLater(
        service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar),
        throwsException,
      );

      expect(integrationRepo.chamadasUpdateSyncState, 0);
      expect(eventRepo.eventos, isEmpty);
    });
  });

  group('CalendarSyncService — tolerância de relógio', () {
    test('diferença pequena (dentro da margem) entre updatedAt e lastSyncedAt NÃO reenvia ao Google', () async {
      final local = _buildLocal(
        id: 'local-1',
        googleEventId: 'g-1',
        googleLastSyncedAt: DateTime(2026, 8, 1, 12, 0, 0),
        updatedAt: DateTime(2026, 8, 1, 12, 0, 2), // 2s de diferença, dentro da margem de 5s
      );
      final eventRepo = _FakeEventRepository([local]);
      final googleRepo = _FakeRemoteCalendarRepository();
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(resultado.atualizados, 0);
      expect(googleRepo.chamadasUpdate, 0);
    });

    test('diferença grande (fora da margem) reenvia ao Google normalmente', () async {
      final local = _buildLocal(
        id: 'local-1',
        googleEventId: 'g-1',
        googleLastSyncedAt: DateTime(2026, 8, 1, 12, 0, 0),
        updatedAt: DateTime(2026, 8, 1, 12, 0, 10), // 10s — fora da margem de 5s
      );
      final eventRepo = _FakeEventRepository([local]);
      final googleRepo = _FakeRemoteCalendarRepository();
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(resultado.atualizados, 1);
      expect(googleRepo.chamadasUpdate, 1);
    });
  });

  group('CalendarSyncService — SyncDirection', () {
    test('apenasImportar: processa o que vem do Google, mas não envia mudanças locais', () async {
      final local = _buildLocal(id: 'local-1'); // sem googleEventId — candidato a ser criado no Google
      final eventRepo = _FakeEventRepository([local]);
      final googleRepo = _FakeRemoteCalendarRepository(eventosParaPuxar: [_buildRemoteEvent(googleId: 'g-novo')]);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(
        userId: _userId,
        defaultCalendarId: _calendarId,
        provider: CalendarProvider.googleCalendar,
        direction: SyncDirection.apenasImportar,
      );

      expect(resultado.criadosNoBussola, 1); // importou o evento do Google
      expect(resultado.criadosNoGoogle, 0); // não tentou enviar o evento local
      expect(googleRepo.chamadasCreate, 0);
    });

    test('apenasExportar: envia mudanças locais, mas não processa o que vem do Google', () async {
      final local = _buildLocal(id: 'local-1'); // sem googleEventId — deve ser criado no Google
      final eventRepo = _FakeEventRepository([local]);
      final googleRepo = _FakeRemoteCalendarRepository(eventosParaPuxar: [_buildRemoteEvent(googleId: 'g-novo')]);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(
        userId: _userId,
        defaultCalendarId: _calendarId,
        provider: CalendarProvider.googleCalendar,
        direction: SyncDirection.apenasExportar,
      );

      expect(resultado.criadosNoBussola, 0); // não importou o evento do Google
      expect(resultado.criadosNoGoogle, 1); // enviou o evento local
      // A busca em si acontece sempre (precisa do nextSyncToken), mas o
      // conteúdo puxado não é processado nesta direção.
      expect(googleRepo.chamadasListar, 1);
    });

    test('ambos (padrão): processa os dois sentidos na mesma rodada', () async {
      final local = _buildLocal(id: 'local-1');
      final eventRepo = _FakeEventRepository([local]);
      final googleRepo = _FakeRemoteCalendarRepository(eventosParaPuxar: [_buildRemoteEvent(googleId: 'g-novo')]);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(resultado.criadosNoBussola, 1);
      expect(resultado.criadosNoGoogle, 1);
    });
  });

  group('CalendarSyncService — syncToken', () {
    test('é salvo (com o novo valor) só depois de uma sincronização concluída com sucesso', () async {
      final eventRepo = _FakeEventRepository();
      final googleRepo = _FakeRemoteCalendarRepository(proximoSyncToken: 'token-abc-123');
      final integrationRepo = _FakeIntegrationRepository(null);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: integrationRepo,
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(integrationRepo.chamadasUpdateSyncState, 1);
      expect(integrationRepo.ultimoSyncTokenSalvo, 'token-abc-123');
    });

    test('não é salvo quando a sincronização falha antes de terminar', () async {
      // Já coberto em detalhe no grupo "falha não corrompe estado local"
      // — repetido aqui, resumido, só para deixar o requisito explícito.
      final eventRepo = _FakeEventRepository();
      final googleRepo = _FakeRemoteCalendarRepository()..erroAoListar = Exception('falha');
      final integrationRepo = _FakeIntegrationRepository(null);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: integrationRepo,
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      await expectLater(service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar), throwsException);

      expect(integrationRepo.chamadasUpdateSyncState, 0);
    });
  });

  group('CalendarSyncService — ordem da orquestração', () {
    test('segue a sequência oficial: download → exclusões locais → upload local → salvar syncToken', () async {
      final ordem = <String>[];
      final eventRepo = _FakeEventRepository([
        _buildLocal(id: 'local-a'), // sem googleEventId: será enviado ao Google (upload)
        _buildLocal(id: 'local-b', googleEventId: 'g-b', deletedAt: DateTime(2026, 8, 1)), // excluído: será removido do Google
      ]);
      final googleRepo = _FakeRemoteCalendarRepository(proximoSyncToken: 'novo-token', log: ordem);
      final integrationRepo = _FakeIntegrationRepository(null, log: ordem);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: integrationRepo,
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      // 'download' (listChangedEvents) é sempre o primeiro; 'save_token'
      // é sempre o último. Entre eles, a sequência oficial manda as
      // exclusões locais → Google ('delete_local_to_google') ANTES do
      // upload de criações/atualizações ('upload_local').
      expect(ordem.first, 'download');
      expect(ordem.last, 'save_token');
      expect(ordem.indexOf('delete_local_to_google'), lessThan(ordem.indexOf('upload_local')));
    });
  });

  group('CalendarSyncService — erro parcial', () {
    test('falha ao processar UM evento do Google não corrompe os que já foram salvos antes dele', () async {
      final eventRepo = _FakeEventRepository()..falharNaCriacaoDeNumero = 2; // a 2ª criação local falha
      final googleRepo = _FakeRemoteCalendarRepository(
        eventosParaPuxar: [
          _buildRemoteEvent(googleId: 'g-1'), // processado com sucesso (1ª criação)
          _buildRemoteEvent(googleId: 'g-2'), // falha aqui (2ª criação)
        ],
      );
      final integrationRepo = _FakeIntegrationRepository(null);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: integrationRepo,
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      await expectLater(service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar), throwsException);

      // O primeiro evento, processado ANTES da falha, continua salvo
      // corretamente — nenhum rollback "mágico" desfaz o que já deu certo.
      expect(eventRepo.eventos.length, 1);
      expect(eventRepo.eventos.first.googleEventId, 'g-1');
      // E o syncToken não foi salvo — a próxima sincronização vai pedir os
      // MESMOS dois eventos de novo ao Google (retry seguro, sem duplicar
      // o que já foi salvo, graças à checagem por `googleEventId`).
      expect(integrationRepo.chamadasUpdateSyncState, 0);
    });
  });

  group('CalendarSyncService — Etapa 1.1: provider parametrizado', () {
    test('Google continua funcionando exatamente igual, usando CalendarProvider.googleCalendar', () async {
      final eventRepo = _FakeEventRepository();
      final googleRepo = _FakeRemoteCalendarRepository(eventosParaPuxar: [_buildRemoteEvent(googleId: 'g-1')]);
      final integrationRepo = _FakeIntegrationRepository(null);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: integrationRepo,
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(
        userId: _userId,
        defaultCalendarId: _calendarId,
        provider: CalendarProvider.googleCalendar,
      );

      expect(resultado.criadosNoBussola, 1);
      expect(integrationRepo.ultimoProviderRecebido, CalendarProvider.googleCalendar);
    });

    test('um provider diferente (ex: outlook) pode ser passado sem nenhuma alteração interna do Service', () async {
      final eventRepo = _FakeEventRepository();
      final googleRepo = _FakeRemoteCalendarRepository(eventosParaPuxar: [_buildRemoteEvent(googleId: 'g-1')]);
      final integrationRepo = _FakeIntegrationRepository(null);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: integrationRepo,
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      // O `RemoteCalendarRepository` injetado ainda é o fake do Google
      // (não existe implementação de Outlook nesta etapa) — o que este
      // teste prova é que o `CalendarSyncService` não trava nem assume
      // nada sobre QUAL provider está sincronizando: ele só repassa o
      // valor recebido para o `IntegrationRepository`, sem hardcode.
      final resultado = await service.syncNow(
        userId: _userId,
        defaultCalendarId: _calendarId,
        provider: CalendarProvider.outlook,
      );

      expect(resultado.criadosNoBussola, 1); // a sincronização funciona normalmente
      expect(integrationRepo.ultimoProviderRecebido, CalendarProvider.outlook);
    });

    test('RemoteCalendarAuthExpiredException leva ao fluxo de reconexão esperado, sem conhecer o erro do Google', () async {
      final eventRepo = _FakeEventRepository();
      final googleRepo = _FakeRemoteCalendarRepository()..erroAoListar = const RemoteCalendarAuthExpiredException('expirado');
      final authService = _FakeGoogleAuthService(
        tokens: ['token-expirado'],
        refreshResultado: const RefreshResult(success: false, reconnectRequired: true),
      );
      final integrationRepo = _FakeIntegrationRepository(null);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: integrationRepo,
        authService: authService,
      );

      await expectLater(
        service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar),
        throwsA(isA<GoogleReconnectRequiredException>()),
      );

      expect(authService.chamadasRefresh, 1);
      expect(integrationRepo.ultimoStatus, IntegrationStatus.desconectado);
    });
  });

  group('CalendarSyncService — Etapa 1.2: autenticação remota abstrata', () {
    test('PROVA ESTRUTURAL: funciona com um fake que só implementa RemoteAuthService, sem NENHUMA relação com GoogleAuthService', () async {
      // `_FakeGoogleAuthService` (usado em TODOS os testes deste arquivo)
      // já é essa prova: `implements RemoteAuthService`, não
      // `extends GoogleAuthService`. Se o `CalendarSyncService` ainda
      // exigisse o tipo concreto do Google em algum lugar, nem este
      // arquivo de teste compilaria. Este teste só torna a alegação
      // explícita, com um nome que documenta a garantia.
      final eventRepo = _FakeEventRepository();
      final googleRepo = _FakeRemoteCalendarRepository(eventosParaPuxar: [_buildRemoteEvent(googleId: 'g-1')]);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(
        userId: _userId,
        defaultCalendarId: _calendarId,
        provider: CalendarProvider.googleCalendar,
      );

      expect(resultado.criadosNoBussola, 1);
    });
  });

  group('CalendarSyncService — vínculo multi-provedor (correção pós-Etapa 1.15)', () {
    test('REGRESSÃO CRÍTICA: um evento local pode ficar vinculado a Google E Outlook ao mesmo tempo, sem um apagar o vínculo do outro', () async {
      // Antes da correção: sincronizar o mesmo evento novo primeiro para o
      // Google e depois para o Outlook fazia o outlookEventId SUBSTITUIR
      // o googleEventId (campo único) — a próxima atualização/exclusão no
      // Google ficaria "órfã", sem saber mais qual era o ID lá.
      final eventoNovo = _buildLocal(id: 'evt-compartilhado');
      final eventRepo = _FakeEventRepository([eventoNovo]);
      final googleRepo = _FakeRemoteCalendarRepository();
      final outlookRepo = _FakeRemoteCalendarRepository();
      final integrationRepo = _FakeIntegrationRepository(null);

      final serviceGoogle = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: integrationRepo,
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );
      await serviceGoogle.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      final depoisDoGoogle = eventRepo.eventos.single;
      expect(depoisDoGoogle.googleEventId, isNotNull);
      expect(depoisDoGoogle.outlookEventId, isNull);

      final serviceOutlook = _buildService(
        eventRepo: eventRepo,
        googleRepo: outlookRepo,
        integrationRepo: integrationRepo,
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );
      await serviceOutlook.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.outlook);

      final depoisDosDois = eventRepo.eventos.single;
      // O ponto central da correção: os DOIS vínculos continuam presentes.
      expect(depoisDosDois.googleEventId, depoisDoGoogle.googleEventId, reason: 'o vínculo com o Google não pode ter sido apagado ao sincronizar com o Outlook');
      expect(depoisDosDois.outlookEventId, isNotNull);
    });

    test('exclusão local propagada só ao provedor certo, preservando o vínculo do outro', () async {
      final eventoVinculadoAosDois = _buildLocal(
        id: 'evt-1',
        googleEventId: 'g-1',
        outlookEventId: 'o-1',
        deletedAt: DateTime(2026, 8, 1),
      );
      final eventRepo = _FakeEventRepository([eventoVinculadoAosDois]);
      final googleRepo = _FakeRemoteCalendarRepository();
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(googleRepo.chamadasDelete, 1); // só excluiu no Google
      final depois = eventRepo.eventos.single;
      expect(depois.googleEventId, isNull); // vínculo do Google limpo
      expect(depois.outlookEventId, 'o-1'); // vínculo do Outlook PRESERVADO — a exclusão foi só no Google
    });

    test('sync_origin grava "outlook" para eventos sincronizados do Outlook, não mais "google" incorretamente', () async {
      final eventRepo = _FakeEventRepository();
      final outlookRepo = _FakeRemoteCalendarRepository(eventosParaPuxar: [_buildRemoteEvent(googleId: 'o-1')]);
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: outlookRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.outlook);

      expect(eventRepo.eventos.single.syncOrigin, SyncOrigin.outlook);
      expect(eventRepo.eventos.single.outlookEventId, 'o-1');
      expect(eventRepo.eventos.single.googleEventId, isNull);
    });
  });

  group('CalendarSyncService — estado de sincronização por provedor (migration 0011)', () {
    test('REGRESSÃO CRÍTICA: sincronizar Google NÃO altera googleLastSyncedAt de forma que interfira no Outlook (outlookLastSyncedAt permanece intocado)', () async {
      final agora = DateTime(2026, 8, 1, 12);
      final local = _buildLocal(
        id: 'evt-1',
        googleEventId: 'g-1',
        outlookEventId: 'o-1',
        updatedAt: agora,
        googleLastSyncedAt: DateTime(2020, 1, 1), // bem antigo — força um push no Google
        outlookLastSyncedAt: agora, // já sincronizado com o Outlook, "em dia"
      );
      final eventRepo = _FakeEventRepository([local]);
      final googleRepo = _FakeRemoteCalendarRepository();
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      final depois = eventRepo.eventos.single;
      // Google foi atualizado (estava desatualizado).
      expect(depois.googleLastSyncedAt, isNot(DateTime(2020, 1, 1)));
      // O estado do OUTLOOK não pode ter mudado — nem o valor, nem a
      // decisão de reenviar (que nem foi avaliada, porque o Service nunca
      // olhou o Outlook nesta rodada).
      expect(depois.outlookLastSyncedAt, agora);
    });

    test('REGRESSÃO CRÍTICA: sincronizar Outlook NÃO altera outlookLastSyncedAt de forma que interfira no Google', () async {
      final agora = DateTime(2026, 8, 1, 12);
      final local = _buildLocal(
        id: 'evt-1',
        googleEventId: 'g-1',
        outlookEventId: 'o-1',
        updatedAt: agora,
        googleLastSyncedAt: agora, // já sincronizado com o Google, "em dia"
        outlookLastSyncedAt: DateTime(2020, 1, 1), // bem antigo — força um push no Outlook
      );
      final eventRepo = _FakeEventRepository([local]);
      final outlookRepo = _FakeRemoteCalendarRepository();
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: outlookRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.outlook);

      final depois = eventRepo.eventos.single;
      expect(depois.outlookLastSyncedAt, isNot(DateTime(2020, 1, 1)));
      // O estado do GOOGLE não pode ter mudado.
      expect(depois.googleLastSyncedAt, agora);
    });

    test('O CENÁRIO REAL QUE CAUSAVA O BUG: uma edição enviada primeiro ao Google chega depois ao Outlook, em vez de ficar perdida para sempre', () async {
      // Antes da correção: sincronizar o Google marcava o campo ÚNICO
      // lastSyncedAt como "em dia" — e quando o Outlook sincronizasse
      // depois (mesmo sem NENHUMA edição nova), ele concluiria, errado,
      // que já tinha essa versão, porque `updatedAt` (fixo, no passado)
      // nunca ficaria depois desse `lastSyncedAt` (atualizado pelo Google
      // por último). Com os campos separados, isso não acontece mais.
      final momentoDaEdicao = DateTime(2026, 8, 1, 9, 0, 0);
      final local = _buildLocal(
        id: 'evt-1',
        googleEventId: 'g-1',
        outlookEventId: 'o-1',
        updatedAt: momentoDaEdicao,
        googleLastSyncedAt: null, // nunca sincronizado com o Google ainda
        outlookLastSyncedAt: null, // nunca sincronizado com o Outlook ainda
      );
      final eventRepo = _FakeEventRepository([local]);

      // Passo 1: sincroniza primeiro com o Google — a edição é enviada para lá.
      final googleRepo = _FakeRemoteCalendarRepository();
      final serviceGoogle = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );
      await serviceGoogle.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);
      expect(googleRepo.chamadasUpdate, 1);

      // Passo 2: sincroniza com o Outlook depois (sem NENHUMA edição nova) — a
      // MESMA edição de `momentoDaEdicao` precisa chegar lá também,
      // porque o Outlook nunca a recebeu.
      final outlookRepo = _FakeRemoteCalendarRepository();
      final serviceOutlook = _buildService(
        eventRepo: eventRepo,
        googleRepo: outlookRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );
      await serviceOutlook.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.outlook);

      expect(outlookRepo.chamadasUpdate, 1, reason: 'a edição precisa chegar ao Outlook — antes da correção, isso ficava perdido para sempre');
    });

    test('Google continua funcionando exatamente como antes da correção', () async {
      final local = _buildLocal(id: 'evt-1', googleEventId: 'g-1', googleLastSyncedAt: DateTime(2020, 1, 1), updatedAt: DateTime(2026, 8, 1, 12));
      final eventRepo = _FakeEventRepository([local]);
      final googleRepo = _FakeRemoteCalendarRepository();
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: googleRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.googleCalendar);

      expect(resultado.atualizados, 1);
      expect(eventRepo.eventos.single.googleSyncOrigin, SyncOrigin.synced);
    });

    test('Outlook funciona corretamente após a correção', () async {
      final local = _buildLocal(id: 'evt-1', outlookEventId: 'o-1', outlookLastSyncedAt: DateTime(2020, 1, 1), updatedAt: DateTime(2026, 8, 1, 12));
      final eventRepo = _FakeEventRepository([local]);
      final outlookRepo = _FakeRemoteCalendarRepository();
      final service = _buildService(
        eventRepo: eventRepo,
        googleRepo: outlookRepo,
        integrationRepo: _FakeIntegrationRepository(null),
        authService: _FakeGoogleAuthService(tokens: ['token-1']),
      );

      final resultado = await service.syncNow(userId: _userId, defaultCalendarId: _calendarId, provider: CalendarProvider.outlook);

      expect(resultado.atualizados, 1);
      expect(eventRepo.eventos.single.outlookSyncOrigin, SyncOrigin.synced);
    });
  });
}

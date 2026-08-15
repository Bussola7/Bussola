import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/data/datasources/outlook_calendar_datasource.dart';
import 'package:bussola/features/integrations/data/mappers/outlook_calendar_mapper.dart';
import 'package:bussola/features/integrations/data/repositories/outlook_calendar_repository.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/services/calendar_sync_service.dart';
import 'package:bussola/features/integrations/domain/services/remote_auth_service.dart';

/// Data Source falso: simula o erro específico do Outlook
/// (`OutlookTokenExpiredException`), um `deltaLink` configurável, e as
/// 4 operações — sem nenhuma chamada HTTP real.
class _FakeOutlookCalendarDataSource extends OutlookCalendarDataSource {
  bool lancarErroExpirado;
  List<OutlookCalendarEvent> eventosParaPuxar;
  String? deltaLinkConfigurado;
  int chamadasListar = 0;
  String? ultimoSyncTokenRecebido;

  _FakeOutlookCalendarDataSource({
    this.lancarErroExpirado = false,
    this.eventosParaPuxar = const [],
    this.deltaLinkConfigurado,
  });

  @override
  Future<({List<OutlookCalendarEvent> events, String? nextSyncToken})> listChangedEvents({
    required String accessToken,
    String? syncToken,
  }) async {
    chamadasListar++;
    ultimoSyncTokenRecebido = syncToken;
    if (lancarErroExpirado) throw OutlookTokenExpiredException();
    return (events: eventosParaPuxar, nextSyncToken: deltaLinkConfigurado);
  }

  @override
  Future<OutlookCalendarEvent> createEvent({required String accessToken, required Map<String, dynamic> eventJson}) async {
    if (lancarErroExpirado) throw OutlookTokenExpiredException();
    throw UnimplementedError();
  }

  @override
  Future<OutlookCalendarEvent> updateEvent({
    required String accessToken,
    required String outlookEventId,
    required Map<String, dynamic> eventJson,
  }) async {
    if (lancarErroExpirado) throw OutlookTokenExpiredException();
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEvent({required String accessToken, required String outlookEventId}) async {
    if (lancarErroExpirado) throw OutlookTokenExpiredException();
  }
}

EventModel _buildEvent({String? outlookEventId}) {
  final now = DateTime.now();
  return EventModel(
    id: 'evt-1',
    calendarId: 'cal-1',
    userId: 'user-1',
    title: 'Evento',
    startDatetime: now,
    endDatetime: now.add(const Duration(hours: 1)),
    timezone: 'America/Sao_Paulo',
    allDay: false,
    outlookEventId: outlookEventId,
    createdAt: now,
    updatedAt: now,
  );
}

OutlookCalendarEvent _buildOutlookEvent({String id = 'outlook-1'}) {
  final now = DateTime.now().toUtc();
  return OutlookCalendarEvent(
    outlookId: id,
    title: 'Evento remoto',
    start: now,
    end: now.add(const Duration(hours: 1)),
    allDay: false,
    cancelled: false,
    updatedAt: now,
  );
}

class _StubRemoteAuthService implements RemoteAuthService {
  @override
  Future<String?> getValidAccessToken(String userId) async => 'token-qualquer';

  @override
  Future<RefreshResult> refreshAccessToken(String userId) async => const RefreshResult(success: false, reconnectRequired: false);
}

void main() {
  group('OutlookCalendarRepository — conversão de erro na fronteira', () {
    test('listChangedEvents: OutlookTokenExpiredException vira RemoteCalendarAuthExpiredException', () async {
      final repo = OutlookCalendarRepository(dataSource: _FakeOutlookCalendarDataSource(lancarErroExpirado: true));

      await expectLater(
        repo.listChangedEvents(accessToken: 'token-qualquer'),
        throwsA(isA<RemoteCalendarAuthExpiredException>()),
      );
    });

    test('createEvent: erro específico do Outlook vira RemoteCalendarAuthExpiredException', () async {
      final repo = OutlookCalendarRepository(dataSource: _FakeOutlookCalendarDataSource(lancarErroExpirado: true));

      await expectLater(
        repo.createEvent(accessToken: 'token-qualquer', event: _buildEvent()),
        throwsA(isA<RemoteCalendarAuthExpiredException>()),
      );
    });

    test('updateEvent: erro específico do Outlook vira RemoteCalendarAuthExpiredException', () async {
      final repo = OutlookCalendarRepository(dataSource: _FakeOutlookCalendarDataSource(lancarErroExpirado: true));

      await expectLater(
        repo.updateEvent(accessToken: 'token-qualquer', event: _buildEvent(outlookEventId: 'outlook-1')),
        throwsA(isA<RemoteCalendarAuthExpiredException>()),
      );
    });

    test('REGRESSÃO (correção pós-Etapa 1.15): updateEvent exige outlookEventId, não mais googleEventId', () async {
      final repo = OutlookCalendarRepository(dataSource: _FakeOutlookCalendarDataSource());

      // Evento sem outlookEventId (mesmo que tivesse um googleEventId, o
      // que nem é o caso aqui) deve ser rejeitado — não existe mais no
      // Outlook até ser criado lá primeiro.
      await expectLater(
        repo.updateEvent(accessToken: 'token-qualquer', event: _buildEvent()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deleteEvent: erro específico do Outlook vira RemoteCalendarAuthExpiredException', () async {
      final repo = OutlookCalendarRepository(dataSource: _FakeOutlookCalendarDataSource(lancarErroExpirado: true));

      await expectLater(
        repo.deleteEvent(accessToken: 'token-qualquer', externalEventId: 'outlook-1'),
        throwsA(isA<RemoteCalendarAuthExpiredException>()),
      );
    });

    test('REGRA: o erro específico do Outlook (OutlookTokenExpiredException) nunca escapa do Repository', () async {
      final repo = OutlookCalendarRepository(dataSource: _FakeOutlookCalendarDataSource(lancarErroExpirado: true));

      try {
        await repo.listChangedEvents(accessToken: 'token-qualquer');
        fail('deveria ter lançado uma exceção');
      } catch (e) {
        expect(e, isNot(isA<OutlookTokenExpiredException>()));
        expect(e, isA<RemoteCalendarAuthExpiredException>());
      }
    });
  });

  group('OutlookCalendarRepository — leitura (deltaLink) e conversão para o tipo genérico', () {
    test('sem erro: devolve os eventos convertidos e o deltaLink recebido do Graph', () async {
      final fakeDataSource = _FakeOutlookCalendarDataSource(
        eventosParaPuxar: [_buildOutlookEvent(id: 'outlook-1'), _buildOutlookEvent(id: 'outlook-2')],
        deltaLinkConfigurado: 'https://graph.microsoft.com/v1.0/me/events/delta?\$deltatoken=abc123',
      );
      final repo = OutlookCalendarRepository(dataSource: fakeDataSource);

      final resultado = await repo.listChangedEvents(accessToken: 'token-qualquer');

      expect(resultado.events.length, 2);
      expect(resultado.events.first.externalId, 'outlook-1');
      expect(resultado.nextSyncToken, 'https://graph.microsoft.com/v1.0/me/events/delta?\$deltatoken=abc123');
    });

    test('repassa o deltaLink guardado (syncToken) na próxima chamada, sem modificar', () async {
      final fakeDataSource = _FakeOutlookCalendarDataSource();
      final repo = OutlookCalendarRepository(dataSource: fakeDataSource);
      const deltaLinkAnterior = 'https://graph.microsoft.com/v1.0/me/events/delta?\$deltatoken=xyz789';

      await repo.listChangedEvents(accessToken: 'token-qualquer', syncToken: deltaLinkAnterior);

      expect(fakeDataSource.ultimoSyncTokenRecebido, deltaLinkAnterior);
    });
  });

  group('OutlookCalendarRepository — compatibilidade com CalendarSyncService (Etapa 1.7)', () {
    test('PROVA ESTRUTURAL: OutlookCalendarRepository pode ser injetado no CalendarSyncService sem nenhuma alteração no Service', () async {
      // Não testa a orquestração em si (já auditada exaustivamente com o
      // Google) — só prova que o tipo é aceito onde o Service espera
      // qualquer RemoteCalendarRepository, exatamente como planejado nas
      // Etapas 1.1/1.3.
      final service = CalendarSyncService(
        remoteRepository: OutlookCalendarRepository(dataSource: _FakeOutlookCalendarDataSource()),
        authService: _StubRemoteAuthService(),
      );

      expect(service, isA<CalendarSyncService>());
    });
  });
}

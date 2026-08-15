import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/domain/entities/remote_calendar_event.dart';
import 'package:bussola/features/integrations/data/models/sync_conflict_model.dart';
import 'package:bussola/features/integrations/data/repositories/integration_repository.dart';
import 'package:bussola/features/integrations/domain/services/sync_conflict_service.dart';

/// Repositório falso: só guarda os conflitos "registrados" em memória,
/// para o teste inspecionar o que o Service decidiu logar.
class _FakeIntegrationRepository extends IntegrationRepository {
  final List<SyncConflictModel> registrados = [];

  @override
  Future<SyncConflictModel> logConflict(SyncConflictModel conflict) async {
    registrados.add(conflict);
    return conflict;
  }
}

EventModel _buildLocalEvent({required DateTime updatedAt}) {
  return EventModel(
    id: 'evt-1',
    calendarId: 'cal-1',
    userId: 'user-1',
    title: 'Evento local',
    startDatetime: DateTime(2026, 8, 1, 9),
    endDatetime: DateTime(2026, 8, 1, 10),
    timezone: 'America/Sao_Paulo',
    allDay: false,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

RemoteCalendarEvent _buildRemoteEvent({required DateTime updatedAt}) {
  return RemoteCalendarEvent(
    externalId: 'google-evt-1',
    title: 'Evento remoto',
    start: DateTime(2026, 8, 1, 9),
    end: DateTime(2026, 8, 1, 10),
    allDay: false,
    status: 'confirmed',
    updatedAt: updatedAt,
  );
}

void main() {
  group('SyncConflictService.resolveUpdatedBothSides', () {
    test('local mais recente vence (last-write-wins)', () async {
      final fakeRepo = _FakeIntegrationRepository();
      final service = SyncConflictService(integrationRepository: fakeRepo);

      final vencedor = await service.resolveUpdatedBothSides(
        userId: 'user-1',
        provider: CalendarProvider.googleCalendar,
        localEvent: _buildLocalEvent(updatedAt: DateTime(2026, 8, 1, 15)),
        remoteEvent: _buildRemoteEvent(updatedAt: DateTime(2026, 8, 1, 12)),
      );

      expect(vencedor, ConflictWinner.local);
      expect(fakeRepo.registrados.single.conflictType, SyncConflictType.updatedBoth);
      expect(fakeRepo.registrados.single.resolutionStrategy, 'last_write_wins');
    });

    test('Remoto mais recente vence', () async {
      final fakeRepo = _FakeIntegrationRepository();
      final service = SyncConflictService(integrationRepository: fakeRepo);

      final vencedor = await service.resolveUpdatedBothSides(
        userId: 'user-1',
        provider: CalendarProvider.googleCalendar,
        localEvent: _buildLocalEvent(updatedAt: DateTime(2026, 8, 1, 10)),
        remoteEvent: _buildRemoteEvent(updatedAt: DateTime(2026, 8, 1, 18)),
      );

      expect(vencedor, ConflictWinner.remote);
    });

    test('sempre registra o conflito, mesmo quando a decisão parece óbvia', () async {
      final fakeRepo = _FakeIntegrationRepository();
      final service = SyncConflictService(integrationRepository: fakeRepo);

      await service.resolveUpdatedBothSides(
        userId: 'user-1',
        provider: CalendarProvider.googleCalendar,
        localEvent: _buildLocalEvent(updatedAt: DateTime(2026, 8, 1, 10)),
        remoteEvent: _buildRemoteEvent(updatedAt: DateTime(2020, 1, 1)),
      );

      expect(fakeRepo.registrados.length, 1);
      expect(fakeRepo.registrados.single.userId, 'user-1');
      expect(fakeRepo.registrados.single.googleEventId, 'google-evt-1');
    });
  });

  group('SyncConflictService.logDeletedOneSide', () {
    test('registra o tipo correto e a estratégia "delete_wins"', () async {
      final fakeRepo = _FakeIntegrationRepository();
      final service = SyncConflictService(integrationRepository: fakeRepo);

      await service.logDeletedOneSide(
        userId: 'user-1',
        provider: CalendarProvider.googleCalendar,
        eventId: 'evt-1',
        googleEventId: 'google-evt-1',
        ladoQueExcluiu: 'google',
      );

      final registrado = fakeRepo.registrados.single;
      expect(registrado.conflictType, SyncConflictType.deletedOneSide);
      expect(registrado.resolutionStrategy, 'delete_wins');
      expect(registrado.resolutionDetails, contains('google'));
    });
  });

  group('SyncConflictService.resolveConcurrentUpdate', () {
    test('resolve por última alteração vence e registra como concurrent_update', () async {
      final fakeRepo = _FakeIntegrationRepository();
      final service = SyncConflictService(integrationRepository: fakeRepo);

      final vencedor = await service.resolveConcurrentUpdate(
        userId: 'user-1',
        provider: CalendarProvider.googleCalendar,
        localEvent: _buildLocalEvent(updatedAt: DateTime(2026, 8, 1, 9, 0, 1)),
        remoteEvent: _buildRemoteEvent(updatedAt: DateTime(2026, 8, 1, 9, 0, 0)),
      );

      expect(vencedor, ConflictWinner.local);
      expect(fakeRepo.registrados.single.conflictType, SyncConflictType.concurrentUpdate);
    });
  });

  group('SyncConflictService — provider gravado corretamente (correção pós-Etapa 1.15)', () {
    test('Google: o conflito é registrado com provider=googleCalendar', () async {
      final fakeRepo = _FakeIntegrationRepository();
      final service = SyncConflictService(integrationRepository: fakeRepo);

      await service.resolveUpdatedBothSides(
        userId: 'user-1',
        provider: CalendarProvider.googleCalendar,
        localEvent: _buildLocalEvent(updatedAt: DateTime(2026, 8, 1, 15)),
        remoteEvent: _buildRemoteEvent(updatedAt: DateTime(2026, 8, 1, 12)),
      );

      expect(fakeRepo.registrados.single.provider, CalendarProvider.googleCalendar);
    });

    test('Outlook: o conflito é registrado com provider=outlook, não mais fixo em Google', () async {
      final fakeRepo = _FakeIntegrationRepository();
      final service = SyncConflictService(integrationRepository: fakeRepo);

      await service.resolveUpdatedBothSides(
        userId: 'user-1',
        provider: CalendarProvider.outlook,
        localEvent: _buildLocalEvent(updatedAt: DateTime(2026, 8, 1, 15)),
        remoteEvent: _buildRemoteEvent(updatedAt: DateTime(2026, 8, 1, 12)),
      );

      expect(fakeRepo.registrados.single.provider, CalendarProvider.outlook);
    });
  });
}

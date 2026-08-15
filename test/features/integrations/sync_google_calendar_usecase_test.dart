import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/domain/entities/remote_calendar_event.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/repositories/remote_calendar_repository.dart';
import 'package:bussola/features/integrations/domain/services/calendar_sync_service.dart';
import 'package:bussola/features/integrations/domain/services/remote_auth_service.dart';
import 'package:bussola/features/integrations/domain/usecases/sync_google_calendar_usecase.dart';

/// Stubs mínimos, só para satisfazer os parâmetros obrigatórios do
/// construtor de `CalendarSyncService` — nunca são realmente chamados,
/// porque `_FakeCalendarSyncService` sobrescreve `syncNow` por completo.
class _StubRemoteCalendarRepository implements RemoteCalendarRepository {
  @override
  Future<({List<RemoteCalendarEvent> events, String? nextSyncToken})> listChangedEvents({
    required String accessToken,
    String? syncToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<RemoteCalendarEvent> createEvent({required String accessToken, required EventModel event}) =>
      throw UnimplementedError();

  @override
  Future<RemoteCalendarEvent> updateEvent({required String accessToken, required EventModel event}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteEvent({required String accessToken, required String externalEventId}) => throw UnimplementedError();
}

class _StubRemoteAuthService implements RemoteAuthService {
  @override
  Future<String?> getValidAccessToken(String userId) => throw UnimplementedError();

  @override
  Future<RefreshResult> refreshAccessToken(String userId) => throw UnimplementedError();
}

class _FakeCalendarSyncService extends CalendarSyncService {
  final SyncResult resultado;
  SyncDirection? direcaoRecebida;
  CalendarProvider? providerRecebido;

  _FakeCalendarSyncService(this.resultado)
      : super(remoteRepository: _StubRemoteCalendarRepository(), authService: _StubRemoteAuthService());

  @override
  Future<SyncResult> syncNow({
    required String userId,
    required String defaultCalendarId,
    required CalendarProvider provider,
    SyncDirection direction = SyncDirection.ambos,
  }) async {
    direcaoRecebida = direction;
    providerRecebido = provider;
    return resultado;
  }
}

void main() {
  group('SyncGoogleCalendarUseCase', () {
    test('repassa a direção escolhida para o service', () async {
      final fake = _FakeCalendarSyncService(const SyncResult(criadosNoBussola: 2));
      final useCase = SyncGoogleCalendarUseCase(syncService: fake);

      final resultado = await useCase.execute(
        userId: 'user-1',
        defaultCalendarId: 'cal-1',
        direction: SyncDirection.apenasImportar,
      );

      expect(resultado.criadosNoBussola, 2);
      expect(fake.direcaoRecebida, SyncDirection.apenasImportar);
    });

    test('usa "ambos" como direção padrão quando não especificado', () async {
      final fake = _FakeCalendarSyncService(const SyncResult());
      final useCase = SyncGoogleCalendarUseCase(syncService: fake);

      await useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(fake.direcaoRecebida, SyncDirection.ambos);
    });

    test('REGRA (Etapa 1.1): sempre passa CalendarProvider.googleCalendar para o Service, que agora é genérico', () async {
      final fake = _FakeCalendarSyncService(const SyncResult());
      final useCase = SyncGoogleCalendarUseCase(syncService: fake);

      await useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(fake.providerRecebido, CalendarProvider.googleCalendar);
    });
  });
}

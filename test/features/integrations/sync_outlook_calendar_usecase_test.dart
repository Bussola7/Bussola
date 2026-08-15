import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/domain/entities/remote_calendar_event.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/repositories/remote_calendar_repository.dart';
import 'package:bussola/features/integrations/domain/services/calendar_sync_service.dart';
import 'package:bussola/features/integrations/domain/services/remote_auth_service.dart';
import 'package:bussola/features/integrations/domain/usecases/sync_outlook_calendar_usecase.dart';

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

/// Fake do Service — o comportamento REAL de "verificar integração",
/// "obter token válido", "token expirado", "reconexão necessária" já é
/// testado exaustivamente em `calendar_sync_service_test.dart` (para
/// qualquer provedor, Outlook incluso desde a Etapa 1.7/1.8). Aqui só
/// interessa provar que o Use Case DELEGA corretamente e não duplica
/// nem interfere em nada disso.
class _FakeCalendarSyncService extends CalendarSyncService {
  final SyncResult? resultadoDeSucesso;
  final Object? erroParaLancar;
  SyncDirection? direcaoRecebida;
  CalendarProvider? providerRecebido;
  int chamadas = 0;

  _FakeCalendarSyncService({this.resultadoDeSucesso, this.erroParaLancar})
      : super(remoteRepository: _StubRemoteCalendarRepository(), authService: _StubRemoteAuthService());

  @override
  Future<SyncResult> syncNow({
    required String userId,
    required String defaultCalendarId,
    required CalendarProvider provider,
    SyncDirection direction = SyncDirection.ambos,
  }) async {
    chamadas++;
    direcaoRecebida = direction;
    providerRecebido = provider;
    if (erroParaLancar != null) throw erroParaLancar!;
    return resultadoDeSucesso!;
  }
}

void main() {
  group('SyncOutlookCalendarUseCase — integração e provider usados corretamente', () {
    test('sempre passa CalendarProvider.outlook para o Service, que é genérico', () async {
      final fake = _FakeCalendarSyncService(resultadoDeSucesso: const SyncResult());
      final useCase = SyncOutlookCalendarUseCase(syncService: fake);

      await useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(fake.providerRecebido, CalendarProvider.outlook);
    });

    test('repassa a direção escolhida para o Service', () async {
      final fake = _FakeCalendarSyncService(resultadoDeSucesso: const SyncResult());
      final useCase = SyncOutlookCalendarUseCase(syncService: fake);

      await useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1', direction: SyncDirection.apenasImportar);

      expect(fake.direcaoRecebida, SyncDirection.apenasImportar);
    });

    test('usa "ambos" como direção padrão quando não especificado', () async {
      final fake = _FakeCalendarSyncService(resultadoDeSucesso: const SyncResult());
      final useCase = SyncOutlookCalendarUseCase(syncService: fake);

      await useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(fake.direcaoRecebida, SyncDirection.ambos);
    });
  });

  group('SyncOutlookCalendarUseCase — sucesso (Outlook conectado, token válido)', () {
    test('devolve o SyncResult exatamente como o Service devolveu, sem alterar nada', () async {
      final fake = _FakeCalendarSyncService(
        resultadoDeSucesso: const SyncResult(criadosNoBussola: 3, criadosNoGoogle: 1, atualizados: 2, excluidos: 1, conflitos: 1),
      );
      final useCase = SyncOutlookCalendarUseCase(syncService: fake);

      final resultado = await useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(resultado.criadosNoBussola, 3);
      expect(resultado.criadosNoGoogle, 1);
      expect(resultado.atualizados, 2);
      expect(resultado.excluidos, 1);
      expect(resultado.conflitos, 1);
    });
  });

  group('SyncOutlookCalendarUseCase — falhas propagadas sem tratamento próprio (sem retry, sem captura)', () {
    test('Outlook desconectado / token ausente (StateError do Service): propaga sem modificar', () async {
      final fake = _FakeCalendarSyncService(erroParaLancar: StateError('Calendário remoto não está conectado ou o token expirou.'));
      final useCase = SyncOutlookCalendarUseCase(syncService: fake);

      await expectLater(
        useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('reconexão necessária (GoogleReconnectRequiredException — contrato genérico já existente): propaga sem modificar', () async {
      final fake = _FakeCalendarSyncService(
        erroParaLancar: const GoogleReconnectRequiredException('A autorização do calendário remoto expirou ou foi revogada. Reconecte sua conta.'),
      );
      final useCase = SyncOutlookCalendarUseCase(syncService: fake);

      await expectLater(
        useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1'),
        throwsA(isA<GoogleReconnectRequiredException>()),
      );
    });

    test('erro genérico do Service: propaga sem envolver numa exceção própria do Use Case', () async {
      final fake = _FakeCalendarSyncService(erroParaLancar: Exception('falha genérica simulada'));
      final useCase = SyncOutlookCalendarUseCase(syncService: fake);

      await expectLater(
        useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1'),
        throwsException,
      );
    });

    test('REGRA: nenhuma tentativa extra é feita pelo Use Case — o Service é chamado exatamente 1 vez, mesmo em caso de erro', () async {
      // Prova que não existe retry próprio no Use Case (isso é
      // responsabilidade exclusiva do CalendarSyncService, já testada
      // separadamente) — se o Use Case tentasse de novo por conta própria,
      // `chamadas` seria maior que 1 aqui.
      final fake = _FakeCalendarSyncService(erroParaLancar: Exception('falha simulada'));
      final useCase = SyncOutlookCalendarUseCase(syncService: fake);

      try {
        await useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1');
      } catch (_) {
        // esperado
      }

      expect(fake.chamadas, 1);
    });
  });

  group('SyncOutlookCalendarUseCase — chamado uma única vez por execução (sem duplicação de lógica)', () {
    test('uma chamada a execute() resulta em exatamente uma chamada a CalendarSyncService.syncNow', () async {
      final fake = _FakeCalendarSyncService(resultadoDeSucesso: const SyncResult());
      final useCase = SyncOutlookCalendarUseCase(syncService: fake);

      await useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(fake.chamadas, 1);
    });

    test('duas chamadas a execute() resultam em exatamente duas chamadas ao Service — nenhuma lógica de sincronização própria acumulada', () async {
      final fake = _FakeCalendarSyncService(resultadoDeSucesso: const SyncResult());
      final useCase = SyncOutlookCalendarUseCase(syncService: fake);

      await useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1');
      await useCase.execute(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(fake.chamadas, 2);
    });
  });
}

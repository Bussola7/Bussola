import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/usecases/connect_google_calendar_usecase.dart';
import 'package:bussola/features/integrations/domain/usecases/disconnect_google_calendar_usecase.dart';
import 'package:bussola/features/integrations/domain/usecases/get_google_integration_status_usecase.dart';
import 'package:bussola/features/integrations/domain/usecases/sync_google_calendar_usecase.dart';
import 'package:bussola/features/integrations/domain/usecases/toggle_google_auto_sync_usecase.dart';
import 'package:bussola/features/integrations/presentation/providers/integration_provider.dart';

class _FakeConnect extends ConnectGoogleCalendarUseCase {
  final bool resultado;
  _FakeConnect(this.resultado);
  @override
  Future<bool> execute() async => resultado;
}

class _FakeDisconnect extends DisconnectGoogleCalendarUseCase {
  bool chamado = false;
  @override
  Future<void> execute(String userId) async => chamado = true;
}

class _FakeGetStatus extends GetGoogleIntegrationStatusUseCase {
  final CalendarIntegrationModel? resultado;
  _FakeGetStatus(this.resultado);
  @override
  Future<CalendarIntegrationModel?> execute(String userId) async => resultado;
}

class _FakeToggleAutoSync extends ToggleGoogleAutoSyncUseCase {
  bool? ultimoValor;
  @override
  Future<void> execute({required String userId, required bool enabled}) async {
    ultimoValor = enabled;
  }
}

/// Sync fake que pode devolver um resultado, ou lançar uma exceção
/// específica — e conta quantas vezes foi chamado, para o teste da trava
/// de sincronizações simultâneas. Também guarda a última [SyncDirection]
/// recebida, para testar a escolha da primeira sincronização.
class _FakeSync extends SyncGoogleCalendarUseCase {
  final Future<SyncResult> Function() acao;
  int chamadas = 0;
  SyncDirection? ultimaDirecao;

  _FakeSync(this.acao);

  @override
  Future<SyncResult> execute({
    required String userId,
    required String defaultCalendarId,
    SyncDirection direction = SyncDirection.ambos,
  }) {
    chamadas++;
    ultimaDirecao = direction;
    return acao();
  }
}

void main() {
  group('IntegrationNotifier — estados básicos', () {
    test('começa desconectado', () {
      final notifier = IntegrationNotifier.forGoogle(
        connect: _FakeConnect(true),
        disconnect: _FakeDisconnect(),
        sync: _FakeSync(() async => const SyncResult()),
        getStatus: _FakeGetStatus(null),
      );

      expect(notifier.state.status, IntegrationStatusUi.disconnected);
    });

    test('connect() bem-sucedido muda para conectado', () async {
      final notifier = IntegrationNotifier.forGoogle(
        connect: _FakeConnect(true),
        disconnect: _FakeDisconnect(),
        sync: _FakeSync(() async => const SyncResult()),
        getStatus: _FakeGetStatus(null),
      );

      final sucesso = await notifier.connect();

      expect(sucesso, true);
      expect(notifier.state.status, IntegrationStatusUi.connected);
    });

    test('connect() cancelado pela pessoa volta para desconectado', () async {
      final notifier = IntegrationNotifier.forGoogle(
        connect: _FakeConnect(false),
        disconnect: _FakeDisconnect(),
        sync: _FakeSync(() async => const SyncResult()),
        getStatus: _FakeGetStatus(null),
      );

      final sucesso = await notifier.connect();

      expect(sucesso, false);
      expect(notifier.state.status, IntegrationStatusUi.disconnected);
    });

    test('disconnect() volta ao estado inicial', () async {
      final fakeDisconnect = _FakeDisconnect();
      final notifier = IntegrationNotifier.forGoogle(
        connect: _FakeConnect(true),
        disconnect: fakeDisconnect,
        sync: _FakeSync(() async => const SyncResult()),
        getStatus: _FakeGetStatus(null),
      );
      await notifier.connect();

      await notifier.disconnect('user-1');

      expect(fakeDisconnect.chamado, true);
      expect(notifier.state.status, IntegrationStatusUi.disconnected);
    });
  });

  group('IntegrationNotifier — sincronização', () {
    test('syncNow() sem conflitos termina em "synced"', () async {
      final notifier = IntegrationNotifier.forGoogle(
        connect: _FakeConnect(true),
        disconnect: _FakeDisconnect(),
        sync: _FakeSync(() async => const SyncResult(criadosNoBussola: 3)),
        getStatus: _FakeGetStatus(null),
      );

      await notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(notifier.state.status, IntegrationStatusUi.synced);
      expect(notifier.state.lastSyncAt, isNotNull);
    });

    test('syncNow() com conflitos termina em "conflict" e guarda a quantidade', () async {
      final notifier = IntegrationNotifier.forGoogle(
        connect: _FakeConnect(true),
        disconnect: _FakeDisconnect(),
        sync: _FakeSync(() async => const SyncResult(conflitos: 2)),
        getStatus: _FakeGetStatus(null),
      );

      await notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(notifier.state.status, IntegrationStatusUi.conflict);
      expect(notifier.state.conflictsInLastSync, 2);
    });

    test('GoogleReconnectRequiredException termina em "tokenExpired" com mensagem amigável', () async {
      final notifier = IntegrationNotifier.forGoogle(
        connect: _FakeConnect(true),
        disconnect: _FakeDisconnect(),
        sync: _FakeSync(() async => throw const GoogleReconnectRequiredException('qualquer coisa técnica')),
        getStatus: _FakeGetStatus(null),
      );

      await notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(notifier.state.status, IntegrationStatusUi.tokenExpired);
      // A mensagem mostrada é a amigável do Notifier, nunca o texto cru da exceção.
      expect(notifier.state.friendlyErrorMessage, isNot(contains('qualquer coisa técnica')));
      expect(notifier.state.friendlyErrorMessage, contains('Reconecte'));
    });

    test('qualquer outra falha termina em "error" com mensagem amigável (nunca a exceção crua)', () async {
      final notifier = IntegrationNotifier.forGoogle(
        connect: _FakeConnect(true),
        disconnect: _FakeDisconnect(),
        sync: _FakeSync(() async => throw Exception('erro técnico interno com detalhes sensíveis')),
        getStatus: _FakeGetStatus(null),
      );

      await notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(notifier.state.status, IntegrationStatusUi.error);
      expect(notifier.state.friendlyErrorMessage, isNot(contains('erro técnico interno')));
    });

    test('REGRA: não permite duas sincronizações simultâneas', () async {
      // A ação demora um pouco, para dar tempo de tentar chamar de novo
      // enquanto a primeira ainda está rodando.
      final fakeSync = _FakeSync(() async {
        await Future.delayed(const Duration(milliseconds: 30));
        return const SyncResult();
      });
      final notifier = IntegrationNotifier.forGoogle(
        connect: _FakeConnect(true),
        disconnect: _FakeDisconnect(),
        sync: fakeSync,
        getStatus: _FakeGetStatus(null),
      );

      final primeira = notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1');
      final segunda = notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1'); // deve ser ignorada
      await Future.wait([primeira, segunda]);

      expect(fakeSync.chamadas, 1);
    });

    test('PRIMEIRA SINCRONIZAÇÃO: a direção escolhida pela pessoa é repassada e guardada no estado', () async {
      final fakeSync = _FakeSync(() async => const SyncResult(criadosNoBussola: 5));
      final notifier = IntegrationNotifier.forGoogle(
        connect: _FakeConnect(true),
        disconnect: _FakeDisconnect(),
        sync: fakeSync,
        getStatus: _FakeGetStatus(null),
      );

      // Antes de qualquer sincronização, o estado sinaliza que ainda
      // precisa perguntar a direção (é isso que a IntegrationsScreen usa
      // para decidir se mostra o diálogo "Como deseja sincronizar?").
      expect(notifier.state.preciseEscolherPrimeiraSincronizacao, true);

      await notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1', direction: SyncDirection.apenasImportar);

      expect(fakeSync.ultimaDirecao, SyncDirection.apenasImportar);
      expect(notifier.state.lastSyncDirection, SyncDirection.apenasImportar);
      expect(notifier.state.preciseEscolherPrimeiraSincronizacao, false);
    });
  });

  group('IntegrationNotifier — loadStatus', () {
    test('sem integração salva, carrega como desconectado', () async {
      final notifier = IntegrationNotifier.forGoogle(
        connect: _FakeConnect(true),
        disconnect: _FakeDisconnect(),
        sync: _FakeSync(() async => const SyncResult()),
        getStatus: _FakeGetStatus(null),
      );

      await notifier.loadStatus('user-1');

      expect(notifier.state.status, IntegrationStatusUi.disconnected);
    });
  });

  group('IntegrationNotifier — sincronização automática (preferência)', () {
    test('setAutoSync atualiza o estado imediatamente e chama o Use Case', () async {
      final fakeToggle = _FakeToggleAutoSync();
      final notifier = IntegrationNotifier.forGoogle(
        connect: _FakeConnect(true),
        disconnect: _FakeDisconnect(),
        sync: _FakeSync(() async => const SyncResult()),
        getStatus: _FakeGetStatus(null),
        toggleAutoSync: fakeToggle,
      );

      expect(notifier.state.autoSyncEnabled, false);

      await notifier.setAutoSync(userId: 'user-1', enabled: true);

      expect(notifier.state.autoSyncEnabled, true);
      expect(fakeToggle.ultimoValor, true);
    });
  });
}

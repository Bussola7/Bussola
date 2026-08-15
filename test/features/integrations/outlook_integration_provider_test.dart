import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/usecases/sync_outlook_calendar_usecase.dart';
import 'package:bussola/features/integrations/presentation/providers/integration_provider.dart';

/// Fake mínimo de `OutlookAuthService` — não estende a classe real (que
/// tem dependências de infraestrutura como `flutter_appauth`/Supabase);
/// implementa só a forma que o `IntegrationNotifier.forOutlook` precisa,
/// via os parâmetros nomeados equivalentes.
class _FakeOutlookAuthService {
  bool resultadoConnect;
  bool desconectarChamado = false;
  String? ultimoUserIdDesconectado;
  CalendarIntegrationModel? statusConfigurado;
  int chamadasGetStatus = 0;

  _FakeOutlookAuthService({this.resultadoConnect = true, this.statusConfigurado});

  Future<bool> connect() async => resultadoConnect;

  Future<void> disconnect({required String userId}) async {
    desconectarChamado = true;
    ultimoUserIdDesconectado = userId;
  }

  Future<CalendarIntegrationModel?> getIntegrationStatus(String userId) async {
    chamadasGetStatus++;
    return statusConfigurado;
  }
}

/// Fake de `SyncOutlookCalendarUseCase` — conta chamadas (prova de "sem
/// duplicação") e pode devolver sucesso ou lançar uma exceção configurada.
class _FakeSyncOutlookUseCase {
  final Future<SyncResult> Function() acao;
  int chamadas = 0;

  _FakeSyncOutlookUseCase(this.acao);

  Future<SyncResult> execute({
    required String userId,
    required String defaultCalendarId,
    SyncDirection direction = SyncDirection.ambos,
  }) {
    chamadas++;
    return acao();
  }
}

CalendarIntegrationModel _buildIntegration({required IntegrationStatus status, DateTime? lastSyncAt}) {
  return CalendarIntegrationModel(
    id: 'int-outlook-1',
    userId: 'user-1',
    provider: CalendarProvider.outlook,
    status: status,
    lastSyncAt: lastSyncAt,
    updatedAt: DateTime.now(),
  );
}

/// Constrói um `IntegrationNotifier` com fakes — como
/// `OutlookAuthService`/`SyncOutlookCalendarUseCase` reais dependem de
/// infraestrutura (flutter_appauth, Supabase), usamos o construtor
/// genérico diretamente aqui (a mesma via que `.forOutlook` usa por
/// dentro), passando as funções dos fakes — prova, de quebra, que o
/// Notifier realmente só depende de funções, não de nenhum tipo concreto.
IntegrationNotifier _buildOutlookNotifier({
  required _FakeOutlookAuthService auth,
  required _FakeSyncOutlookUseCase sync,
}) {
  return IntegrationNotifier(
    connect: auth.connect,
    disconnect: (userId) => auth.disconnect(userId: userId),
    sync: sync.execute,
    getStatus: auth.getIntegrationStatus,
  );
}

void main() {
  group('IntegrationNotifier.forOutlook — status', () {
    test('sem integração salva: carrega como desconectado', () async {
      final auth = _FakeOutlookAuthService(statusConfigurado: null);
      final notifier = _buildOutlookNotifier(auth: auth, sync: _FakeSyncOutlookUseCase(() async => const SyncResult()));

      await notifier.loadStatus('user-1');

      expect(notifier.state.status, IntegrationStatusUi.disconnected);
      expect(auth.chamadasGetStatus, 1);
    });

    test('integração conectada: carrega status/lastSyncAt corretamente', () async {
      final ultimaSync = DateTime(2026, 8, 1, 10);
      final auth = _FakeOutlookAuthService(
        statusConfigurado: _buildIntegration(status: IntegrationStatus.conectado, lastSyncAt: ultimaSync),
      );
      final notifier = _buildOutlookNotifier(auth: auth, sync: _FakeSyncOutlookUseCase(() async => const SyncResult()));

      await notifier.loadStatus('user-1');

      expect(notifier.state.status, IntegrationStatusUi.connected);
      expect(notifier.state.lastSyncAt, ultimaSync);
    });
  });

  group('IntegrationNotifier.forOutlook — connect', () {
    test('sucesso: muda para connected', () async {
      final auth = _FakeOutlookAuthService(resultadoConnect: true);
      final notifier = _buildOutlookNotifier(auth: auth, sync: _FakeSyncOutlookUseCase(() async => const SyncResult()));

      final sucesso = await notifier.connect();

      expect(sucesso, true);
      expect(notifier.state.status, IntegrationStatusUi.connected);
    });

    test('cancelado pela pessoa: volta para disconnected, não é erro', () async {
      final auth = _FakeOutlookAuthService(resultadoConnect: false);
      final notifier = _buildOutlookNotifier(auth: auth, sync: _FakeSyncOutlookUseCase(() async => const SyncResult()));

      final sucesso = await notifier.connect();

      expect(sucesso, false);
      expect(notifier.state.status, IntegrationStatusUi.disconnected);
    });
  });

  group('IntegrationNotifier.forOutlook — disconnect', () {
    test('chama o OutlookAuthService.disconnect com o userId certo, mesmo com o parâmetro nomeado', () async {
      final auth = _FakeOutlookAuthService();
      final notifier = _buildOutlookNotifier(auth: auth, sync: _FakeSyncOutlookUseCase(() async => const SyncResult()));

      await notifier.disconnect('user-1');

      expect(auth.desconectarChamado, true);
      expect(auth.ultimoUserIdDesconectado, 'user-1');
      expect(notifier.state.status, IntegrationStatusUi.disconnected);
    });
  });

  group('IntegrationNotifier.forOutlook — sincronização: loading/sucesso/erro/reconexão', () {
    test('durante a sincronização, o estado passa por "syncing"', () async {
      final auth = _FakeOutlookAuthService();
      final fakeSync = _FakeSyncOutlookUseCase(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        return const SyncResult();
      });
      final notifier = _buildOutlookNotifier(auth: auth, sync: fakeSync);

      final future = notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1');
      // Logo depois de disparar, ainda deve estar "syncing" (a ação do fake demora 10ms).
      expect(notifier.state.status, IntegrationStatusUi.syncing);
      await future;
    });

    test('sucesso sem conflito: termina em "synced" com SyncResult aplicado', () async {
      final auth = _FakeOutlookAuthService();
      final fakeSync = _FakeSyncOutlookUseCase(() async => const SyncResult(criadosNoBussola: 4));
      final notifier = _buildOutlookNotifier(auth: auth, sync: fakeSync);

      await notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(notifier.state.status, IntegrationStatusUi.synced);
      expect(notifier.state.lastSyncAt, isNotNull);
    });

    test('erro genérico: termina em "error" com mensagem amigável, nunca a exceção crua', () async {
      final auth = _FakeOutlookAuthService();
      final fakeSync = _FakeSyncOutlookUseCase(() async => throw Exception('detalhe técnico sensível do Outlook'));
      final notifier = _buildOutlookNotifier(auth: auth, sync: fakeSync);

      await notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(notifier.state.status, IntegrationStatusUi.error);
      expect(notifier.state.friendlyErrorMessage, isNot(contains('detalhe técnico')));
    });

    test('RECONEXÃO NECESSÁRIA (GoogleReconnectRequiredException — contrato genérico já existente): termina em "tokenExpired"', () async {
      final auth = _FakeOutlookAuthService();
      final fakeSync = _FakeSyncOutlookUseCase(() async => throw const GoogleReconnectRequiredException('token do Outlook expirado'));
      final notifier = _buildOutlookNotifier(auth: auth, sync: fakeSync);

      await notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1');

      expect(notifier.state.status, IntegrationStatusUi.tokenExpired);
      expect(notifier.state.friendlyErrorMessage, contains('Reconecte'));
    });
  });

  group('IntegrationNotifier.forOutlook — sem chamada duplicada', () {
    test('duas sincronizações simultâneas: SyncOutlookCalendarUseCase chamado só 1 vez', () async {
      final auth = _FakeOutlookAuthService();
      final fakeSync = _FakeSyncOutlookUseCase(() async {
        await Future.delayed(const Duration(milliseconds: 30));
        return const SyncResult();
      });
      final notifier = _buildOutlookNotifier(auth: auth, sync: fakeSync);

      final primeira = notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1');
      final segunda = notifier.syncNow(userId: 'user-1', defaultCalendarId: 'cal-1'); // deve ser ignorada
      await Future.wait([primeira, segunda]);

      expect(fakeSync.chamadas, 1);
    });
  });

  group('IntegrationNotifier.forOutlook — auto-sync não suportado ainda', () {
    test('setAutoSync não quebra (no-op seguro) quando o provedor não suporta a preferência', () async {
      final auth = _FakeOutlookAuthService();
      final notifier = _buildOutlookNotifier(auth: auth, sync: _FakeSyncOutlookUseCase(() async => const SyncResult()));

      // Não deve lançar exceção nenhuma, mesmo sem toggleAutoSync configurado.
      await notifier.setAutoSync(userId: 'user-1', enabled: true);

      expect(notifier.state.autoSyncEnabled, false); // não muda, porque não há UseCase para persistir isso ainda
    });
  });

  group('IntegrationNotifier.forOutlook — fábrica de verdade (SyncOutlookCalendarUseCase real, prova de tipo)', () {
    test('IntegrationNotifier.forOutlook() aceita SyncOutlookCalendarUseCase real como parâmetro', () {
      // Não executa (evitaria tocar em infraestrutura real) — só prova
      // que a fábrica compila e aceita os tipos reais do domínio.
      expect(() => IntegrationNotifier.forOutlook(sync: SyncOutlookCalendarUseCase()), returnsNormally);
    });
  });
}

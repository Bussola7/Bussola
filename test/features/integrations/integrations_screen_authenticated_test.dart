import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bussola/features/auth/data/auth_repository.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/presentation/providers/integration_provider.dart';
import 'package:bussola/features/integrations/presentation/screens/integrations_screen.dart';

/// Repositório de auth falso — sobrescreve só o `currentUser` (getter),
/// nunca toca `SupabaseService.client` de verdade.
class _FakeAuthRepository extends AuthRepository {
  @override
  User? get currentUser => _usuarioFalso;
}

/// `User` REAL do `supabase_flutter` — construtor confirmado na
/// documentação oficial (pub.dev/documentation/gotrue/latest/gotrue/User-class.html),
/// não inventado. Só os campos obrigatórios + os que a tela usa (`id`).
final _usuarioFalso = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime.now().toIso8601String(),
);

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier() : super(repository: _FakeAuthRepository());
}

/// Constrói um `IntegrationNotifier` com comportamento configurável — o
/// mesmo construtor genérico que `.forGoogle()`/`.forOutlook()` usam por
/// dentro (Etapa 1.10), então serve para os dois provedores no teste.
IntegrationNotifier _fakeNotifier({
  bool connectResult = true,
  Duration connectDelay = Duration.zero,
  CalendarIntegrationModel? status,
  Future<SyncResult> Function()? syncAction,
  Duration syncDelay = Duration.zero,
}) {
  return IntegrationNotifier(
    connect: () async {
      if (connectDelay > Duration.zero) await Future.delayed(connectDelay);
      return connectResult;
    },
    disconnect: (_) async {},
    sync: ({required userId, required defaultCalendarId, SyncDirection direction = SyncDirection.ambos}) async {
      if (syncDelay > Duration.zero) await Future.delayed(syncDelay);
      if (syncAction != null) return syncAction();
      return const SyncResult();
    },
    getStatus: (_) async => status,
  );
}

CalendarIntegrationModel _integracaoConectada({DateTime? lastSyncAt}) {
  return CalendarIntegrationModel(
    id: 'int-1',
    userId: 'user-1',
    provider: CalendarProvider.outlook,
    status: IntegrationStatus.conectado,
    lastSyncAt: lastSyncAt,
    updatedAt: DateTime.now(),
  );
}

Widget _buildApp({
  required IntegrationNotifier outlookNotifier,
  IntegrationNotifier? googleNotifier,
}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier()),
      outlookIntegrationNotifierProvider.overrideWith((ref) => outlookNotifier),
      integrationNotifierProvider.overrideWith((ref) => googleNotifier ?? _fakeNotifier()),
    ],
    child: const MaterialApp(home: IntegrationsScreen()),
  );
}

void main() {
  group('IntegrationsScreen — Outlook desconectado', () {
    testWidgets('mostra a mensagem de conexão e o botão certo, com o Google renderizando ao lado', (tester) async {
      await tester.pumpWidget(_buildApp(outlookNotifier: _fakeNotifier(status: null)));
      await tester.pumpAndSettle();

      expect(find.text('Conecte seu Outlook Calendar ao Bússola para manter seus compromissos sincronizados.'), findsOneWidget);
      expect(find.text('Conectar Outlook Calendar'), findsOneWidget);
      // Google, com o fake padrão (sem integração salva), também aparece desconectado.
      expect(find.text('Google Calendar'), findsOneWidget);
      expect(find.text('Outlook Calendar'), findsOneWidget);
    });
  });

  group('IntegrationsScreen — Outlook conectando', () {
    testWidgets('mostra "Conectando..." durante a chamada assíncrona', (tester) async {
      await tester.pumpWidget(_buildApp(outlookNotifier: _fakeNotifier(connectDelay: const Duration(milliseconds: 200))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Conectar Outlook Calendar'));
      await tester.pump(); // um frame — a chamada ainda está "no ar"

      expect(find.text('Conectando...'), findsOneWidget);

      await tester.pumpAndSettle(); // termina a espera para não vazar timer pendente
    });
  });

  group('IntegrationsScreen — Outlook conectado', () {
    testWidgets('mostra status conectado, sem o alternador de sincronização automática', (tester) async {
      await tester.pumpWidget(_buildApp(outlookNotifier: _fakeNotifier(status: _integracaoConectada())));
      await tester.pumpAndSettle();

      expect(find.text('🟢 Conectado'), findsOneWidget);
      expect(find.text('Sincronizar agora'), findsWidgets);
      expect(find.text('Desconectar'), findsWidgets);
      // REGRA: Outlook não tem auto-sync — o alternador não pode aparecer no bloco do Outlook.
      // (o Google, com o fake padrão desconectado, também não mostra o alternador aqui,
      // então esperamos ZERO ocorrências no total.)
      expect(find.text('Sincronização automática'), findsNothing);
    });
  });

  group('IntegrationsScreen — Outlook desconectar (ação, não um estado visual próprio)', () {
    // NOTA: `IntegrationStatusUi` não tem um valor "desconectando" — o
    // disconnect() não passa por nenhum estado intermediário visível (vai
    // direto para `disconnected` depois do await). Por isso este teste
    // cobre a AÇÃO (tocar em "Desconectar" leva a desconectado), não um
    // estado de carregamento que não existe no design atual.
    testWidgets('tocar em "Desconectar" leva de volta ao estado desconectado', (tester) async {
      await tester.pumpWidget(_buildApp(outlookNotifier: _fakeNotifier(status: _integracaoConectada())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Desconectar'));
      await tester.pumpAndSettle();

      expect(find.text('Conectar Outlook Calendar'), findsOneWidget);
    });
  });

  group('IntegrationsScreen — Outlook sincronizando', () {
    testWidgets('mostra "Sincronizando..." durante a chamada assíncrona', (tester) async {
      await tester.pumpWidget(_buildApp(
        outlookNotifier: _fakeNotifier(status: _integracaoConectada(), syncDelay: const Duration(milliseconds: 200)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sincronizar agora'));
      await tester.pump();

      expect(find.text('Sincronizando...'), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });

  group('IntegrationsScreen — Outlook sucesso da sincronização', () {
    testWidgets('após sincronizar com sucesso, volta a mostrar conectado/sincronizado', (tester) async {
      await tester.pumpWidget(_buildApp(
        outlookNotifier: _fakeNotifier(status: _integracaoConectada(), syncAction: () async => const SyncResult(criadosNoBussola: 2)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sincronizar agora'));
      await tester.pumpAndSettle();

      expect(find.text('🟢 Conectado'), findsOneWidget);
      expect(find.textContaining('Última sincronização: Hoje'), findsOneWidget);
    });
  });

  group('IntegrationsScreen — Outlook erro', () {
    testWidgets('mostra mensagem amigável, nunca a exceção crua', (tester) async {
      await tester.pumpWidget(_buildApp(
        outlookNotifier: _fakeNotifier(
          status: _integracaoConectada(),
          syncAction: () async => throw Exception('detalhe técnico sensível'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sincronizar agora'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível sincronizar agora. Tente novamente em instantes.'), findsOneWidget);
      expect(find.textContaining('detalhe técnico sensível'), findsNothing);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });
  });

  group('IntegrationsScreen — Outlook reconexão necessária', () {
    testWidgets('mostra o botão de reconectar quando a autorização expira', (tester) async {
      await tester.pumpWidget(_buildApp(
        outlookNotifier: _fakeNotifier(
          status: _integracaoConectada(),
          syncAction: () async => throw const GoogleReconnectRequiredException('token expirado'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sincronizar agora'));
      await tester.pumpAndSettle();

      expect(find.text('Sua conexão expirou. Reconecte para continuar sincronizando.'), findsOneWidget);
      expect(find.text('Reconectar Outlook Calendar'), findsOneWidget);
    });
  });

  group('IntegrationsScreen — Google continua funcionando normalmente ao lado do Outlook', () {
    testWidgets('Google conectado e Outlook desconectado, simultaneamente, sem interferência', (tester) async {
      final googleConectado = CalendarIntegrationModel(
        id: 'int-google-1',
        userId: 'user-1',
        provider: CalendarProvider.googleCalendar,
        status: IntegrationStatus.conectado,
        autoSyncEnabled: true,
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(_buildApp(
        outlookNotifier: _fakeNotifier(status: null),
        googleNotifier: _fakeNotifier(status: googleConectado),
      ));
      await tester.pumpAndSettle();

      // Google: conectado, COM o alternador de auto-sync.
      expect(find.text('Sincronização automática'), findsOneWidget);
      // Outlook: continua desconectado, sem interferência do estado do Google.
      expect(find.text('Conectar Outlook Calendar'), findsOneWidget);
    });
  });
}

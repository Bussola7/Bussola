import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bussola/features/auth/data/auth_repository.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/integrations/presentation/screens/integrations_screen.dart';

/// Repositório de auth falso — sobrescreve só o `currentUser` (getter) para
/// nunca tocar `SupabaseService.client` de verdade. Sem isso, o
/// `AuthNotifier` real tentaria acessar o SDK do Supabase, que não está
/// inicializado em teste de widget puro.
class _FakeAuthRepository extends AuthRepository {
  @override
  User? get currentUser => null;
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier() : super(repository: _FakeAuthRepository());
}

void main() {
  group('IntegrationsScreen — widget (Etapa 1.11)', () {
    testWidgets('sem login: mostra a mensagem de login para os DOIS blocos (Google e Outlook)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier()),
          ],
          child: const MaterialApp(home: IntegrationsScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Google Calendar'), findsOneWidget);
      expect(find.text('Outlook Calendar'), findsOneWidget);
      expect(find.text('Faça login para conectar seu Google Calendar.'), findsOneWidget);
      expect(find.text('Faça login para conectar seu Outlook Calendar.'), findsOneWidget);
    });

    testWidgets('a AppBar mostra o título "Integrações"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _FakeAuthNotifier()),
          ],
          child: const MaterialApp(home: IntegrationsScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Integrações'), findsOneWidget);
    });
  });
}

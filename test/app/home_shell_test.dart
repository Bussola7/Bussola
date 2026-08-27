import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:bussola/app/home_shell.dart';
import 'package:bussola/features/agenda/domain/services/day_summary_service.dart';
import 'package:bussola/features/agenda/domain/services/schedule_analyzer_service.dart';
import 'package:bussola/features/agenda/domain/usecases/get_day_intelligence_usecase.dart';
import 'package:bussola/features/agenda/presentation/providers/category_provider.dart';
import 'package:bussola/features/agenda/presentation/providers/day_intelligence_provider.dart';
import 'package:bussola/features/auth/data/auth_repository.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/dashboard/presentation/providers/insight_provider.dart';
import 'package:bussola/features/goals/presentation/providers/goal_provider.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/shared/widgets/area_filter_chip.dart';

class _FakeAuthRepository extends AuthRepository {
  final User _user;
  _FakeAuthRepository(this._user);

  @override
  User? get currentUser => _user;
}

class _NoOpTaskNotifier extends TaskNotifier {
  @override
  Future<void> load(String userId) async {}
}

class _NoOpGoalNotifier extends GoalNotifier {
  @override
  Future<void> load(String userId) async {}
}

class _NoOpCategoryNotifier extends CategoryNotifier {
  @override
  Future<void> load(String userId) async {}
}

DayIntelligence _buildDayIntelligence() {
  return const DayIntelligence(
    analysis: DayScheduleAnalysis(
      eventCount: 0,
      busyDuration: Duration.zero,
      freeDuration: Duration.zero,
      largestFreeInterval: null,
      smallestFreeInterval: null,
      focusBlocks: [],
      completedCount: 0,
      pendingCount: 0,
    ),
    summary: DaySummary(
      eventCount: 0,
      importantMeetingsCount: 0,
      freeDuration: Duration.zero,
      largestFreeInterval: null,
      closingRemark: '',
      nextAction: NextAction(texto: '', rotuloBotao: '', destino: NextActionDestino.agenda),
    ),
    events: [],
  );
}

void main() {
  testWidgets(
    'fluxo real: tocar na área → ir pra Tarefas → tocar no X do chip → trocar de aba → voltar — filtro não reaparece',
    (tester) async {
      final user = User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        email: 'weberth@teste.com',
        createdAt: '2026-08-01T10:00:00.000Z',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => AuthNotifier(repository: _FakeAuthRepository(user))),
            taskNotifierProvider.overrideWith((ref) => _NoOpTaskNotifier()),
            goalNotifierProvider.overrideWith((ref) => _NoOpGoalNotifier()),
            categoryNotifierProvider.overrideWith((ref) => _NoOpCategoryNotifier()),
            dayIntelligenceProvider.overrideWith((ref, userId) async => _buildDayIntelligence()),
            weeklyEventsProvider.overrideWith((ref, userId) async => const []),
          ],
          child: const MaterialApp(home: HomeShell()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Toca no ícone "Saúde" em "Áreas da vida", na Hoje — precisa
      // rolar até ele primeiro, pois fica abaixo da altura padrão da
      // viewport de teste.
      await tester.ensureVisible(find.text('Saúde'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saúde'));
      await tester.pumpAndSettle();

      // 2. O menu abre perguntando onde ver — toca em "Tarefas".
      expect(find.widgetWithText(ListTile, 'Tarefas'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Tarefas'));
      await tester.pumpAndSettle();

      // Chegou em Tarefas já filtrada por Saúde.
      expect(find.byType(AreaFilterChip), findsOneWidget);
      expect(find.textContaining('Saúde'), findsWidgets);

      // 3. Toca no "X" do chip pra limpar o filtro.
      await tester.tap(find.byTooltip('Limpar filtro'));
      await tester.pumpAndSettle();
      expect(find.byType(AreaFilterChip), findsNothing, reason: 'O chip deveria sumir assim que limpar');

      // 4. Troca pra outra aba pela navegação inferior.
      await tester.tap(find.text('Início'));
      await tester.pumpAndSettle();

      // 5. Volta pra Tarefas pela navegação inferior.
      await tester.tap(find.text('Tarefas'));
      await tester.pumpAndSettle();

      // O filtro limpo não pode ter reaparecido sozinho.
      expect(
        find.byType(AreaFilterChip),
        findsNothing,
        reason: 'O filtro limpo não deveria reaparecer ao voltar pra Tarefas pela navegação inferior',
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/dashboard/presentation/widgets/performance_summary_card.dart';
import 'package:bussola/features/goals/presentation/providers/goal_provider.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/shared/models/life_area.dart';

TaskModel _buildTask({required String id, required TaskStatus status, DateTime? completedAt}) {
  final now = DateTime.now();
  return TaskModel(
    id: id,
    userId: 'user-1',
    title: 'Tarefa $id',
    area: LifeArea.pessoal,
    status: status,
    completedAt: completedAt,
    createdAt: now,
    updatedAt: now,
  );
}

/// Notifier com estado fixo, sem tocar em repositório/Supabase — `load`
/// é um no-op de propósito, o estado já vem pronto do teste.
class _FixedTaskNotifier extends TaskNotifier {
  _FixedTaskNotifier(List<TaskModel> tasks) {
    state = TaskListState(tasks: tasks);
  }

  @override
  Future<void> load(String userId) async {}
}

class _NoOpGoalNotifier extends GoalNotifier {
  @override
  Future<void> load(String userId) async {}
}

void main() {
  testWidgets('"Tarefas concluídas hoje" conta só as concluídas hoje, não o total histórico da conta', (tester) async {
    final hoje = DateTime.now();
    final diasAtras = hoje.subtract(const Duration(days: 3));
    final tasks = [
      _buildTask(id: '1', status: TaskStatus.concluida, completedAt: hoje),
      _buildTask(id: '2', status: TaskStatus.concluida, completedAt: hoje),
      // Concluída há 3 dias — contava no total histórico (bug antigo), mas
      // não deve contar no card, que mostra só "hoje".
      _buildTask(id: '3', status: TaskStatus.concluida, completedAt: diasAtras),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskNotifierProvider.overrideWith((ref) => _FixedTaskNotifier(tasks)),
          goalNotifierProvider.overrideWith((ref) => _NoOpGoalNotifier()),
        ],
        child: const MaterialApp(home: Scaffold(body: PerformanceSummaryCard(userId: 'user-1'))),
      ),
    );

    expect(find.text('Tarefas concluídas hoje'), findsOneWidget);
    // As 3 tarefas estão "concluida", mas só 2 têm completedAt de hoje.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });
}

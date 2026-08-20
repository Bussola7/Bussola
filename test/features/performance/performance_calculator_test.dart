import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/performance/domain/performance_calculator.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/shared/models/life_area.dart';

TaskModel _buildTask({
  String id = 'task-1',
  Priority priority = Priority.media,
  TaskStatus status = TaskStatus.pendente,
  DateTime? completedAt,
}) {
  final now = DateTime.now();
  return TaskModel(
    id: id,
    userId: 'user-1',
    title: 'Tarefa',
    area: LifeArea.pessoal,
    priority: priority,
    status: status,
    completedAt: completedAt,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final calculator = PerformanceCalculator();

  group('PerformanceCalculator.prioridadesConcluidas', () {
    test('conta só tarefas concluídas de prioridade Alta ou Muito Alta', () {
      final tasks = [
        _buildTask(id: '1', priority: Priority.muitoAlta, status: TaskStatus.concluida),
        _buildTask(id: '2', priority: Priority.alta, status: TaskStatus.concluida),
        _buildTask(id: '3', priority: Priority.media, status: TaskStatus.concluida), // média não conta
        _buildTask(id: '4', priority: Priority.alta, status: TaskStatus.pendente), // não concluída não conta
        _buildTask(id: '5', priority: Priority.baixa, status: TaskStatus.concluida), // baixa não conta
      ];

      expect(calculator.prioridadesConcluidas(tasks), 2);
    });

    test('retorna 0 quando não há tarefas', () {
      expect(calculator.prioridadesConcluidas([]), 0);
    });
  });

  group('PerformanceCalculator.evolucaoSemanal', () {
    test('retorna 7 posições, uma por dia, hoje incluso como último item', () {
      final hoje = DateTime(2026, 8, 19);
      final tasks = [
        _buildTask(id: '1', completedAt: DateTime(2026, 8, 19, 10)), // hoje
        _buildTask(id: '2', completedAt: DateTime(2026, 8, 18, 15)), // ontem
        _buildTask(id: '3', completedAt: DateTime(2026, 8, 13, 9)), // 6 dias atrás (primeiro dia da janela)
      ];

      final evolucao = calculator.evolucaoSemanal(tasks, agora: hoje);

      expect(evolucao.length, 7);
      expect(evolucao.last, 1); // hoje
      expect(evolucao[5], 1); // ontem
      expect(evolucao.first, 1); // 6 dias atrás
      expect(evolucao.sublist(1, 5), everyElement(0));
    });

    test('ignora tarefas sem completedAt e tarefas concluídas fora da janela de 7 dias', () {
      final hoje = DateTime(2026, 8, 19);
      final tasks = [
        _buildTask(id: '1', completedAt: null),
        _buildTask(id: '2', completedAt: DateTime(2026, 8, 1)), // fora da janela
      ];

      final evolucao = calculator.evolucaoSemanal(tasks, agora: hoje);

      expect(evolucao, everyElement(0));
    });

    test('soma corretamente quando várias tarefas foram concluídas no mesmo dia', () {
      final hoje = DateTime(2026, 8, 19);
      final tasks = [
        _buildTask(id: '1', completedAt: DateTime(2026, 8, 19, 8)),
        _buildTask(id: '2', completedAt: DateTime(2026, 8, 19, 20)),
        _buildTask(id: '3', completedAt: DateTime(2026, 8, 19, 23, 59)),
      ];

      final evolucao = calculator.evolucaoSemanal(tasks, agora: hoje);

      expect(evolucao.last, 3);
    });
  });
}

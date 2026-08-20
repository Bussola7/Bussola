import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/dashboard/domain/dashboard_calculator.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/shared/models/life_area.dart';

TaskModel _buildTask({
  String id = 'task-1',
  String title = 'Tarefa',
  Priority priority = Priority.media,
  TaskStatus status = TaskStatus.pendente,
  DateTime? completedAt,
}) {
  final now = DateTime.now();
  return TaskModel(
    id: id,
    userId: 'user-1',
    title: title,
    area: LifeArea.pessoal,
    priority: priority,
    status: status,
    completedAt: completedAt,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final calculator = DashboardCalculator();

  group('DashboardCalculator.prioridades', () {
    test('devolve só pendentes, ordenadas da prioridade mais alta para a mais baixa', () {
      final tasks = [
        _buildTask(id: 'baixa', priority: Priority.baixa),
        _buildTask(id: 'muito-alta', priority: Priority.muitoAlta),
        _buildTask(id: 'media', priority: Priority.media),
        _buildTask(id: 'alta', priority: Priority.alta),
      ];

      final resultado = calculator.prioridades(tasks);

      expect(resultado.map((t) => t.id), ['muito-alta', 'alta', 'media']); // top 3
    });

    test('ignora tarefas já concluídas', () {
      final tasks = [
        _buildTask(id: 'concluida', priority: Priority.muitoAlta, status: TaskStatus.concluida),
        _buildTask(id: 'pendente', priority: Priority.baixa),
      ];

      final resultado = calculator.prioridades(tasks);

      expect(resultado.map((t) => t.id), ['pendente']);
    });

    test('limita a 3 tarefas mesmo havendo mais pendentes', () {
      final tasks = List.generate(5, (i) => _buildTask(id: 'task-$i', priority: Priority.alta));

      expect(calculator.prioridades(tasks).length, 3);
    });

    test('lista vazia quando não há tarefas pendentes', () {
      final tasks = [_buildTask(status: TaskStatus.concluida)];
      expect(calculator.prioridades(tasks), isEmpty);
    });
  });

  group('DashboardCalculator.concluidasHoje', () {
    test('conta só tarefas com completedAt igual ao dia de referência', () {
      final hoje = DateTime(2026, 8, 19);
      final tasks = [
        _buildTask(id: '1', completedAt: DateTime(2026, 8, 19, 8)),
        _buildTask(id: '2', completedAt: DateTime(2026, 8, 19, 22)),
        _buildTask(id: '3', completedAt: DateTime(2026, 8, 18)), // ontem, não conta
        _buildTask(id: '4', completedAt: null), // não conta
      ];

      expect(calculator.concluidasHoje(tasks, agora: hoje), 2);
    });

    test('retorna 0 quando nenhuma tarefa foi concluída hoje', () {
      final hoje = DateTime(2026, 8, 19);
      final tasks = [_buildTask(completedAt: DateTime(2026, 8, 1))];

      expect(calculator.concluidasHoje(tasks, agora: hoje), 0);
    });
  });

  group('DashboardCalculator.formatarData', () {
    test('formata a data por extenso, em português', () {
      expect(calculator.formatarData(DateTime(2026, 8, 19)), '19 de agosto');
      expect(calculator.formatarData(DateTime(2026, 1, 1)), '1 de janeiro');
      expect(calculator.formatarData(DateTime(2026, 12, 25)), '25 de dezembro');
    });
  });
}

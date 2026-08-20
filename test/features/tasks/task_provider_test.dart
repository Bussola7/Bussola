import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/features/tasks/data/repositories/task_repository.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/shared/models/life_area.dart';

TaskModel _buildTask({
  String id = 'task-1',
  String title = 'Tarefa',
  Priority priority = Priority.media,
  TaskStatus status = TaskStatus.pendente,
  DateTime? dueDate,
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
    dueDate: dueDate,
    completedAt: completedAt,
    createdAt: now,
    updatedAt: now,
  );
}

/// Repositório falso: guarda as tarefas em memória, sem tocar no Supabase.
/// Permite forçar erro no `getAll` para testar o tratamento de falha do
/// notifier, e registra o payload da última chamada a `update`.
class _FakeTaskRepository extends TaskRepository {
  final List<TaskModel> existentes;
  final bool falharAoCarregar;
  TaskModel? lastUpdated;

  _FakeTaskRepository({this.existentes = const [], this.falharAoCarregar = false});

  @override
  Future<List<TaskModel>> getAll(String userId) async {
    if (falharAoCarregar) throw Exception('Falha simulada de rede');
    return existentes;
  }

  @override
  Future<TaskModel> create(TaskModel task) async => task;

  @override
  Future<TaskModel> update(TaskModel task) async {
    lastUpdated = task;
    return task;
  }

  @override
  Future<void> delete(String id) async {}
}

void main() {
  group('TaskNotifier.load', () {
    test('popula o estado com as tarefas carregadas', () async {
      final repo = _FakeTaskRepository(existentes: [_buildTask(id: 'task-1'), _buildTask(id: 'task-2')]);
      final notifier = TaskNotifier(repository: repo);

      await notifier.load('user-1');

      expect(notifier.state.tasks.length, 2);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, null);
    });

    test('em caso de erro, mantém a lista vazia e define errorMessage', () async {
      final repo = _FakeTaskRepository(falharAoCarregar: true);
      final notifier = TaskNotifier(repository: repo);

      await notifier.load('user-1');

      expect(notifier.state.tasks, isEmpty);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, isNotNull);
    });
  });

  group('TaskNotifier.create', () {
    test('adiciona a tarefa criada ao estado', () async {
      final notifier = TaskNotifier(repository: _FakeTaskRepository());

      await notifier.create(_buildTask(id: 'nova'));

      expect(notifier.state.tasks.map((t) => t.id), contains('nova'));
    });
  });

  group('TaskNotifier.update', () {
    test('substitui só a tarefa atualizada, mantendo as outras', () async {
      final repo = _FakeTaskRepository();
      final notifier = TaskNotifier(repository: repo);
      await notifier.create(_buildTask(id: 'task-1', title: 'Original'));
      await notifier.create(_buildTask(id: 'task-2', title: 'Outra'));

      await notifier.update(_buildTask(id: 'task-1', title: 'Editada'));

      final atualizada = notifier.state.tasks.firstWhere((t) => t.id == 'task-1');
      expect(atualizada.title, 'Editada');
      expect(notifier.state.tasks.firstWhere((t) => t.id == 'task-2').title, 'Outra');
    });
  });

  group('TaskNotifier.toggleConcluida', () {
    test('marca uma tarefa pendente como concluída e define completedAt', () async {
      final repo = _FakeTaskRepository();
      final notifier = TaskNotifier(repository: repo);
      final pendente = _buildTask(id: 'task-1', status: TaskStatus.pendente);
      await notifier.create(pendente);

      await notifier.toggleConcluida(pendente);

      expect(repo.lastUpdated?.status, TaskStatus.concluida);
      expect(repo.lastUpdated?.completedAt, isNotNull);
    });

    test('desmarca uma tarefa concluída, voltando para pendente e limpando completedAt', () async {
      final repo = _FakeTaskRepository();
      final notifier = TaskNotifier(repository: repo);
      final concluida = _buildTask(id: 'task-1', status: TaskStatus.concluida, completedAt: DateTime.now());
      await notifier.create(concluida);

      await notifier.toggleConcluida(concluida);

      expect(repo.lastUpdated?.status, TaskStatus.pendente);
      expect(repo.lastUpdated?.completedAt, null);
    });
  });

  group('TaskNotifier.delete', () {
    test('remove a tarefa do estado', () async {
      final notifier = TaskNotifier(repository: _FakeTaskRepository());
      await notifier.create(_buildTask(id: 'task-1'));
      await notifier.create(_buildTask(id: 'task-2'));

      await notifier.delete('task-1');

      expect(notifier.state.tasks.map((t) => t.id), ['task-2']);
    });
  });

  group('TaskListState', () {
    test('pendentes/concluidas/atrasadas/hoje separam as tarefas corretamente', () {
      final ontem = DateTime.now().subtract(const Duration(days: 1));
      final hoje = DateTime.now();

      final state = TaskListState(tasks: [
        _buildTask(id: 'pendente', status: TaskStatus.pendente),
        _buildTask(id: 'concluida', status: TaskStatus.concluida),
        _buildTask(id: 'atrasada', status: TaskStatus.pendente, dueDate: DateTime(ontem.year, ontem.month, ontem.day)),
        _buildTask(id: 'hoje', status: TaskStatus.pendente, dueDate: DateTime(hoje.year, hoje.month, hoje.day)),
      ]);

      expect(state.pendentes.map((t) => t.id), containsAll(['pendente', 'atrasada', 'hoje']));
      expect(state.concluidas.map((t) => t.id), ['concluida']);
      expect(state.atrasadas.map((t) => t.id), ['atrasada']);
      expect(state.hoje.map((t) => t.id), ['hoje']);
    });
  });
}

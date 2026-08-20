import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/features/tasks/data/repositories/task_repository.dart';

class TaskListState {
  final List<TaskModel> tasks;
  final bool isLoading;
  final String? errorMessage;

  const TaskListState({this.tasks = const [], this.isLoading = false, this.errorMessage});

  List<TaskModel> get pendentes => tasks.where((t) => !t.isConcluida).toList();
  List<TaskModel> get concluidas => tasks.where((t) => t.isConcluida).toList();
  List<TaskModel> get atrasadas => tasks.where((t) => t.isAtrasada).toList();
  List<TaskModel> get hoje => tasks.where((t) => t.isHoje && !t.isConcluida).toList();

  TaskListState copyWith({List<TaskModel>? tasks, bool? isLoading, String? errorMessage}) {
    return TaskListState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class TaskNotifier extends StateNotifier<TaskListState> {
  final TaskRepository _repository;

  TaskNotifier({TaskRepository? repository}) : _repository = repository ?? TaskRepository(), super(const TaskListState());

  Future<void> load(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final tasks = await _repository.getAll(userId);
      state = state.copyWith(tasks: tasks, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'Não foi possível carregar as tarefas.');
    }
  }

  Future<void> create(TaskModel task) async {
    final criada = await _repository.create(task);
    state = state.copyWith(tasks: [...state.tasks, criada]);
  }

  Future<void> update(TaskModel task) async {
    final atualizada = await _repository.update(task);
    state = state.copyWith(tasks: [for (final t in state.tasks) if (t.id == atualizada.id) atualizada else t]);
  }

  Future<void> toggleConcluida(TaskModel task) async {
    final atualizada = task.copyWith(
      status: task.isConcluida ? TaskStatus.pendente : TaskStatus.concluida,
      completedAt: task.isConcluida ? null : DateTime.now(),
      clearCompletedAt: task.isConcluida,
    );
    await update(atualizada);
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    state = state.copyWith(tasks: state.tasks.where((t) => t.id != id).toList());
  }
}

final taskNotifierProvider = StateNotifierProvider<TaskNotifier, TaskListState>((ref) => TaskNotifier());

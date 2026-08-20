import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/features/goals/data/models/goal_model.dart';
import 'package:bussola/features/goals/data/repositories/goal_repository.dart';

class GoalListState {
  final List<GoalModel> goals;
  final bool isLoading;
  final String? errorMessage;

  const GoalListState({this.goals = const [], this.isLoading = false, this.errorMessage});

  List<GoalModel> get emAndamento => goals.where((g) => !g.isConcluido).toList();
  List<GoalModel> get concluidos => goals.where((g) => g.isConcluido).toList();

  GoalListState copyWith({List<GoalModel>? goals, bool? isLoading, String? errorMessage}) {
    return GoalListState(
      goals: goals ?? this.goals,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class GoalNotifier extends StateNotifier<GoalListState> {
  final GoalRepository _repository;

  GoalNotifier({GoalRepository? repository}) : _repository = repository ?? GoalRepository(), super(const GoalListState());

  Future<void> load(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final goals = await _repository.getAll(userId);
      state = state.copyWith(goals: goals, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'Não foi possível carregar os objetivos.');
    }
  }

  Future<void> create(GoalModel goal) async {
    final criado = await _repository.create(goal);
    state = state.copyWith(goals: [...state.goals, criado]);
  }

  Future<void> update(GoalModel goal) async {
    final atualizado = await _repository.update(goal);
    state = state.copyWith(goals: [for (final g in state.goals) if (g.id == atualizado.id) atualizado else g]);
  }

  /// Atualiza o percentual — marca como concluído automaticamente ao
  /// chegar em 100%, e volta para "em andamento" se descer de 100%.
  Future<void> setProgress(GoalModel goal, int novoPercentual) async {
    final concluido = novoPercentual >= 100;
    final atualizado = goal.copyWith(
      progressPercent: novoPercentual.clamp(0, 100),
      status: concluido ? GoalStatus.concluido : GoalStatus.emAndamento,
      completedAt: concluido ? DateTime.now() : null,
      clearCompletedAt: !concluido,
    );
    await update(atualizado);
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    state = state.copyWith(goals: state.goals.where((g) => g.id != id).toList());
  }
}

final goalNotifierProvider = StateNotifierProvider<GoalNotifier, GoalListState>((ref) => GoalNotifier());

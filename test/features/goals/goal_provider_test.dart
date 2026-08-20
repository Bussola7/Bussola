import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/goals/data/models/goal_model.dart';
import 'package:bussola/features/goals/data/repositories/goal_repository.dart';
import 'package:bussola/features/goals/presentation/providers/goal_provider.dart';
import 'package:bussola/shared/models/life_area.dart';

GoalModel _buildGoal({
  String id = 'goal-1',
  String title = 'Objetivo',
  int progressPercent = 0,
  GoalStatus status = GoalStatus.emAndamento,
  DateTime? completedAt,
}) {
  final now = DateTime.now();
  return GoalModel(
    id: id,
    userId: 'user-1',
    title: title,
    area: LifeArea.pessoal,
    progressPercent: progressPercent,
    status: status,
    completedAt: completedAt,
    createdAt: now,
    updatedAt: now,
  );
}

/// Repositório falso: guarda os objetivos em memória, sem tocar no
/// Supabase. Permite forçar erro no `getAll` e registra o payload da
/// última chamada a `update`.
class _FakeGoalRepository extends GoalRepository {
  final List<GoalModel> existentes;
  final bool falharAoCarregar;
  GoalModel? lastUpdated;

  _FakeGoalRepository({this.existentes = const [], this.falharAoCarregar = false});

  @override
  Future<List<GoalModel>> getAll(String userId) async {
    if (falharAoCarregar) throw Exception('Falha simulada de rede');
    return existentes;
  }

  @override
  Future<GoalModel> create(GoalModel goal) async => goal;

  @override
  Future<GoalModel> update(GoalModel goal) async {
    lastUpdated = goal;
    return goal;
  }

  @override
  Future<void> delete(String id) async {}
}

void main() {
  group('GoalNotifier.load', () {
    test('popula o estado com os objetivos carregados', () async {
      final repo = _FakeGoalRepository(existentes: [_buildGoal(id: 'goal-1'), _buildGoal(id: 'goal-2')]);
      final notifier = GoalNotifier(repository: repo);

      await notifier.load('user-1');

      expect(notifier.state.goals.length, 2);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, null);
    });

    test('em caso de erro, mantém a lista vazia e define errorMessage', () async {
      final repo = _FakeGoalRepository(falharAoCarregar: true);
      final notifier = GoalNotifier(repository: repo);

      await notifier.load('user-1');

      expect(notifier.state.goals, isEmpty);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, isNotNull);
    });
  });

  group('GoalNotifier.create', () {
    test('adiciona o objetivo criado ao estado', () async {
      final notifier = GoalNotifier(repository: _FakeGoalRepository());

      await notifier.create(_buildGoal(id: 'novo'));

      expect(notifier.state.goals.map((g) => g.id), contains('novo'));
    });
  });

  group('GoalNotifier.update', () {
    test('substitui só o objetivo atualizado, mantendo os outros', () async {
      final repo = _FakeGoalRepository();
      final notifier = GoalNotifier(repository: repo);
      await notifier.create(_buildGoal(id: 'goal-1', title: 'Original'));
      await notifier.create(_buildGoal(id: 'goal-2', title: 'Outro'));

      await notifier.update(_buildGoal(id: 'goal-1', title: 'Editado'));

      final atualizado = notifier.state.goals.firstWhere((g) => g.id == 'goal-1');
      expect(atualizado.title, 'Editado');
      expect(notifier.state.goals.firstWhere((g) => g.id == 'goal-2').title, 'Outro');
    });
  });

  group('GoalNotifier.setProgress', () {
    test('ao atingir 100%, marca como concluído e define completedAt', () async {
      final repo = _FakeGoalRepository();
      final notifier = GoalNotifier(repository: repo);
      final emAndamento = _buildGoal(id: 'goal-1', progressPercent: 80);
      await notifier.create(emAndamento);

      await notifier.setProgress(emAndamento, 100);

      expect(repo.lastUpdated?.progressPercent, 100);
      expect(repo.lastUpdated?.status, GoalStatus.concluido);
      expect(repo.lastUpdated?.completedAt, isNotNull);
    });

    test('REGRESSÃO: ao descer de 100%, volta para em andamento e limpa completedAt', () async {
      final repo = _FakeGoalRepository();
      final notifier = GoalNotifier(repository: repo);
      final concluido = _buildGoal(id: 'goal-1', progressPercent: 100, status: GoalStatus.concluido, completedAt: DateTime.now());
      await notifier.create(concluido);

      await notifier.setProgress(concluido, 70);

      expect(repo.lastUpdated?.progressPercent, 70);
      expect(repo.lastUpdated?.status, GoalStatus.emAndamento);
      expect(repo.lastUpdated?.completedAt, null);
    });

    test('limita o percentual entre 0 e 100', () async {
      final repo = _FakeGoalRepository();
      final notifier = GoalNotifier(repository: repo);
      final goal = _buildGoal(id: 'goal-1');
      await notifier.create(goal);

      await notifier.setProgress(goal, 150);
      expect(repo.lastUpdated?.progressPercent, 100);

      await notifier.setProgress(goal, -10);
      expect(repo.lastUpdated?.progressPercent, 0);
    });
  });

  group('GoalNotifier.delete', () {
    test('remove o objetivo do estado', () async {
      final notifier = GoalNotifier(repository: _FakeGoalRepository());
      await notifier.create(_buildGoal(id: 'goal-1'));
      await notifier.create(_buildGoal(id: 'goal-2'));

      await notifier.delete('goal-1');

      expect(notifier.state.goals.map((g) => g.id), ['goal-2']);
    });
  });

  group('GoalListState', () {
    test('emAndamento/concluidos separam os objetivos pelo status', () {
      final state = GoalListState(goals: [
        _buildGoal(id: 'ativo', status: GoalStatus.emAndamento),
        _buildGoal(id: 'feito', status: GoalStatus.concluido),
      ]);

      expect(state.emAndamento.map((g) => g.id), ['ativo']);
      expect(state.concluidos.map((g) => g.id), ['feito']);
    });
  });
}

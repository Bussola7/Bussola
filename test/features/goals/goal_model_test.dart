import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/goals/data/models/goal_model.dart';
import 'package:bussola/shared/models/life_area.dart';

void main() {
  group('GoalModel', () {
    final json = {
      'id': 'goal-1',
      'user_id': 'user-1',
      'title': 'Aprender Flutter',
      'description': 'Terminar o MVP do Bússola',
      'area': 'profissional',
      'due_date': '2026-12-31',
      'progress_percent': 40,
      'status': 'em_andamento',
      'completed_at': null,
      'created_at': '2026-08-01T10:00:00.000Z',
      'updated_at': '2026-08-01T10:00:00.000Z',
    };

    test('fromJson lê todos os campos corretamente', () {
      final goal = GoalModel.fromJson(json);

      expect(goal.id, 'goal-1');
      expect(goal.title, 'Aprender Flutter');
      expect(goal.area, LifeArea.profissional);
      expect(goal.dueDate, DateTime.parse('2026-12-31'));
      expect(goal.progressPercent, 40);
      expect(goal.status, GoalStatus.emAndamento);
      expect(goal.completedAt, null);
    });

    test('fromJson usa os padrões (área pessoal, progresso 0, em andamento) quando não informados', () {
      final minimo = {
        'id': 'goal-2',
        'user_id': 'user-1',
        'title': 'Objetivo simples',
        'description': null,
        'due_date': null,
        'completed_at': null,
        'created_at': '2026-08-01T10:00:00.000Z',
        'updated_at': '2026-08-01T10:00:00.000Z',
      };
      final goal = GoalModel.fromJson(minimo);

      expect(goal.area, LifeArea.pessoal);
      expect(goal.progressPercent, 0);
      expect(goal.status, GoalStatus.emAndamento);
    });

    test('toInsertJson envia área/status no formato do banco e due_date só como data (sem hora)', () {
      final goal = GoalModel.fromJson(json);
      final insertJson = goal.toInsertJson(userId: 'user-1');

      expect(insertJson['area'], 'profissional');
      expect(insertJson['status'], 'em_andamento');
      expect(insertJson['progress_percent'], 40);
      expect(insertJson['due_date'], '2026-12-31');
      expect(insertJson['user_id'], 'user-1');
    });

    test('toInsertJson envia status "concluido" quando concluído', () {
      final goal = GoalModel.fromJson({...json, 'status': 'concluido'});
      expect(goal.toInsertJson(userId: 'user-1')['status'], 'concluido');
    });

    test('copyWith troca só o campo pedido e mantém o resto', () {
      final goal = GoalModel.fromJson(json);
      final atualizado = goal.copyWith(title: 'Novo título');

      expect(atualizado.title, 'Novo título');
      expect(atualizado.id, goal.id);
      expect(atualizado.progressPercent, goal.progressPercent);
      expect(atualizado.dueDate, goal.dueDate);
    });

    test('copyWith com clearDueDate remove o prazo mesmo se um novo dueDate for passado junto', () {
      final goal = GoalModel.fromJson(json);
      final semPrazo = goal.copyWith(clearDueDate: true, dueDate: DateTime(2026, 12, 25));

      expect(semPrazo.dueDate, null);
    });

    test('copyWith com clearCompletedAt limpa completedAt mesmo passando completedAt: null junto com outros campos', () {
      final concluido = GoalModel.fromJson({...json, 'status': 'concluido', 'completed_at': '2026-08-05T10:00:00.000Z'});
      expect(concluido.completedAt, isNotNull);

      final reaberto = concluido.copyWith(status: GoalStatus.emAndamento, completedAt: null, clearCompletedAt: true);

      expect(reaberto.completedAt, null);
      expect(reaberto.status, GoalStatus.emAndamento);
    });

    test('isConcluido reflete o status', () {
      final emAndamento = GoalModel.fromJson(json);
      final concluido = GoalModel.fromJson({...json, 'status': 'concluido'});

      expect(emAndamento.isConcluido, false);
      expect(concluido.isConcluido, true);
    });
  });
}

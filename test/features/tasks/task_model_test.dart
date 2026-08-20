import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/shared/models/life_area.dart';

void main() {
  group('TaskModel', () {
    final json = {
      'id': 'task-1',
      'user_id': 'user-1',
      'title': 'Enviar proposta',
      'description': 'Revisar valores antes de enviar',
      'area': 'profissional',
      'priority': 'alta',
      'status': 'pendente',
      'due_date': '2026-08-10',
      'completed_at': null,
      'created_at': '2026-08-01T10:00:00.000Z',
      'updated_at': '2026-08-01T10:00:00.000Z',
    };

    test('fromJson lê todos os campos corretamente', () {
      final task = TaskModel.fromJson(json);

      expect(task.id, 'task-1');
      expect(task.title, 'Enviar proposta');
      expect(task.area, LifeArea.profissional);
      expect(task.priority, Priority.alta);
      expect(task.status, TaskStatus.pendente);
      expect(task.dueDate, DateTime.parse('2026-08-10'));
      expect(task.completedAt, null);
    });

    test('fromJson usa os padrões (área pessoal, prioridade média, status pendente) quando não informados', () {
      final minimo = {
        'id': 'task-2',
        'user_id': 'user-1',
        'title': 'Tarefa simples',
        'description': null,
        'due_date': null,
        'completed_at': null,
        'created_at': '2026-08-01T10:00:00.000Z',
        'updated_at': '2026-08-01T10:00:00.000Z',
      };
      final task = TaskModel.fromJson(minimo);

      expect(task.area, LifeArea.pessoal);
      expect(task.priority, Priority.media);
      expect(task.status, TaskStatus.pendente);
    });

    test('toInsertJson envia área/prioridade/status no formato do banco e due_date só como data (sem hora)', () {
      final task = TaskModel.fromJson(json);
      final insertJson = task.toInsertJson(userId: 'user-1');

      expect(insertJson['area'], 'profissional');
      expect(insertJson['priority'], 'alta');
      expect(insertJson['status'], 'pendente');
      expect(insertJson['due_date'], '2026-08-10');
      expect(insertJson['user_id'], 'user-1');
    });

    test('copyWith troca só o campo pedido e mantém o resto', () {
      final task = TaskModel.fromJson(json);
      final atualizada = task.copyWith(title: 'Novo título');

      expect(atualizada.title, 'Novo título');
      expect(atualizada.id, task.id);
      expect(atualizada.priority, task.priority);
      expect(atualizada.dueDate, task.dueDate);
    });

    test('copyWith com clearDueDate remove o prazo mesmo se um novo dueDate for passado junto', () {
      final task = TaskModel.fromJson(json);
      final semPrazo = task.copyWith(clearDueDate: true, dueDate: DateTime(2026, 12, 25));

      expect(semPrazo.dueDate, null);
    });

    test('isConcluida reflete o status', () {
      final pendente = TaskModel.fromJson(json);
      final concluida = TaskModel.fromJson({...json, 'status': 'concluida'});

      expect(pendente.isConcluida, false);
      expect(concluida.isConcluida, true);
    });

    group('isAtrasada', () {
      test('true quando tem prazo no passado e não está concluída', () {
        final ontem = DateTime.now().subtract(const Duration(days: 1));
        final task = TaskModel.fromJson({
          ...json,
          'due_date': '${ontem.year.toString().padLeft(4, '0')}-${ontem.month.toString().padLeft(2, '0')}-${ontem.day.toString().padLeft(2, '0')}',
        });

        expect(task.isAtrasada, true);
      });

      test('false quando não tem prazo definido', () {
        final task = TaskModel.fromJson({...json, 'due_date': null});
        expect(task.isAtrasada, false);
      });

      test('false quando o prazo já passou mas a tarefa está concluída', () {
        final ontem = DateTime.now().subtract(const Duration(days: 1));
        final task = TaskModel.fromJson({
          ...json,
          'due_date': '${ontem.year.toString().padLeft(4, '0')}-${ontem.month.toString().padLeft(2, '0')}-${ontem.day.toString().padLeft(2, '0')}',
          'status': 'concluida',
        });

        expect(task.isAtrasada, false);
      });

      test('false quando o prazo é hoje ou no futuro', () {
        final hoje = DateTime.now();
        final task = TaskModel.fromJson({
          ...json,
          'due_date': '${hoje.year.toString().padLeft(4, '0')}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}',
        });

        expect(task.isAtrasada, false);
      });
    });

    group('isHoje', () {
      test('true quando o prazo é hoje', () {
        final hoje = DateTime.now();
        final task = TaskModel.fromJson({
          ...json,
          'due_date': '${hoje.year.toString().padLeft(4, '0')}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}',
        });

        expect(task.isHoje, true);
      });

      test('false quando não tem prazo, ou o prazo não é hoje', () {
        final semPrazo = TaskModel.fromJson({...json, 'due_date': null});
        expect(semPrazo.isHoje, false);

        final amanha = DateTime.now().add(const Duration(days: 1));
        final comPrazoFuturo = TaskModel.fromJson({
          ...json,
          'due_date': '${amanha.year.toString().padLeft(4, '0')}-${amanha.month.toString().padLeft(2, '0')}-${amanha.day.toString().padLeft(2, '0')}',
        });
        expect(comPrazoFuturo.isHoje, false);
      });
    });
  });
}

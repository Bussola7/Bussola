import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/models/agenda_item.dart';
import 'package:bussola/features/agenda/domain/services/agenda_list_builder.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';

TaskModel _buildTask({
  String id = 'task-1',
  String title = 'Tarefa',
  DateTime? dueDate,
  TaskStatus status = TaskStatus.pendente,
}) {
  final now = DateTime.now();
  return TaskModel(
    id: id,
    userId: 'user-1',
    title: title,
    dueDate: dueDate,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

EventModel _buildEvent({
  String id = 'evt-1',
  String title = 'Evento',
  required DateTime start,
  DateTime? end,
  bool allDay = false,
  EventStatus status = EventStatus.confirmado,
  DateTime? deletedAt,
}) {
  final now = DateTime.now();
  return EventModel(
    id: id,
    calendarId: 'cal-1',
    userId: 'user-1',
    title: title,
    startDatetime: start,
    endDatetime: end ?? start.add(const Duration(hours: 1)),
    timezone: 'America/Sao_Paulo',
    allDay: allDay,
    status: status,
    deletedAt: deletedAt,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final builder = AgendaListBuilder();
  final inicioMes = DateTime(2026, 3, 1);
  final fimMes = DateTime(2026, 4, 1);

  group('AgendaListBuilder.build', () {
    test('agrupa tarefas e eventos do mesmo dia juntos', () {
      final resultado = builder.build(
        tasks: [_buildTask(id: 't1', dueDate: DateTime(2026, 3, 10))],
        events: [_buildEvent(id: 'e1', start: DateTime(2026, 3, 10, 14))],
        start: inicioMes,
        end: fimMes,
      );

      expect(resultado.keys, contains(DateTime(2026, 3, 10)));
      expect(resultado[DateTime(2026, 3, 10)]!.map((i) => i.id), containsAll(['t1', 'e1']));
    });

    test('ignora tarefas sem prazo (não têm dia para entrar na lista)', () {
      final resultado = builder.build(
        tasks: [_buildTask(id: 't1', dueDate: null)],
        events: const [],
        start: inicioMes,
        end: fimMes,
      );

      expect(resultado, isEmpty);
    });

    test('ignora itens fora do período pedido', () {
      final resultado = builder.build(
        tasks: [_buildTask(id: 't1', dueDate: DateTime(2026, 2, 28))],
        events: [_buildEvent(id: 'e1', start: DateTime(2026, 4, 1, 10))],
        start: inicioMes,
        end: fimMes,
      );

      expect(resultado, isEmpty);
    });

    test('ignora eventos excluídos (soft delete)', () {
      final resultado = builder.build(
        tasks: const [],
        events: [_buildEvent(id: 'e1', start: DateTime(2026, 3, 10, 14), deletedAt: DateTime(2026, 3, 5))],
        start: inicioMes,
        end: fimMes,
      );

      expect(resultado, isEmpty);
    });

    test('dentro do dia, itens sem horário vêm antes dos com horário', () {
      final resultado = builder.build(
        tasks: [_buildTask(id: 'tarefa', dueDate: DateTime(2026, 3, 10))],
        events: [_buildEvent(id: 'evento', start: DateTime(2026, 3, 10, 9))],
        start: inicioMes,
        end: fimMes,
      );

      final doDia = resultado[DateTime(2026, 3, 10)]!;
      expect(doDia.first.id, 'tarefa');
      expect(doDia.last.id, 'evento');
    });

    test('dentro do dia, eventos com horário ficam em ordem crescente', () {
      final resultado = builder.build(
        tasks: const [],
        events: [
          _buildEvent(id: 'tarde', start: DateTime(2026, 3, 10, 15)),
          _buildEvent(id: 'manha', start: DateTime(2026, 3, 10, 9)),
        ],
        start: inicioMes,
        end: fimMes,
      );

      final doDia = resultado[DateTime(2026, 3, 10)]!;
      expect(doDia.map((i) => i.id).toList(), ['manha', 'tarde']);
    });

    test('evento de dia inteiro fica sem horário (junto dos "sem horário")', () {
      final resultado = builder.build(
        tasks: const [],
        events: [_buildEvent(id: 'e1', start: DateTime(2026, 3, 10), allDay: true)],
        start: inicioMes,
        end: fimMes,
      );

      expect(resultado[DateTime(2026, 3, 10)]!.single.horario, null);
    });
  });

  group('AgendaItem', () {
    test('etiqueta de tarefa é "Tarefa"', () {
      final item = AgendaItem.fromTask(_buildTask(dueDate: DateTime(2026, 3, 10)));
      expect(item.etiqueta, 'Tarefa');
      expect(item.type, AgendaItemType.tarefa);
    });

    test('etiqueta de evento é "Horário"', () {
      final item = AgendaItem.fromEvent(_buildEvent(start: DateTime(2026, 3, 10, 14)));
      expect(item.etiqueta, 'Horário');
      expect(item.type, AgendaItemType.evento);
    });

    test('tarefa concluída fica marcada como finalizado', () {
      final item = AgendaItem.fromTask(_buildTask(dueDate: DateTime(2026, 3, 10), status: TaskStatus.concluida));
      expect(item.finalizado, true);
    });

    test('evento cancelado fica marcado como finalizado', () {
      final item = AgendaItem.fromEvent(
        _buildEvent(start: DateTime(2026, 3, 10, 14), status: EventStatus.cancelado),
      );
      expect(item.finalizado, true);
    });
  });
}

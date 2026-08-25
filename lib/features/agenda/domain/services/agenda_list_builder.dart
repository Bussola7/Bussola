import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/models/agenda_item.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';

/// Monta a lista unificada (tarefas + eventos) da visão "Lista" da Agenda:
/// filtra pelo período visível, agrupa por dia e ordena por horário dentro
/// de cada dia — itens sem horário (tarefa, evento de dia inteiro) vêm
/// primeiro. Lógica pura, sem tocar em provider nem widget, para poder
/// testar sem levantar uma árvore de widgets.
class AgendaListBuilder {
  Map<DateTime, List<AgendaItem>> build({
    required List<TaskModel> tasks,
    required List<EventModel> events,
    required DateTime start,
    required DateTime end,
  }) {
    final itens = <AgendaItem>[
      for (final t in tasks)
        if (t.dueDate != null && _dentroDoPeriodo(t.dueDate!, start, end)) AgendaItem.fromTask(t),
      for (final e in events)
        if (!e.isDeleted && _dentroDoPeriodo(e.startDatetime.toLocal(), start, end)) AgendaItem.fromEvent(e),
    ];

    final porDia = <DateTime, List<AgendaItem>>{};
    for (final item in itens) {
      porDia.putIfAbsent(item.data, () => []).add(item);
    }
    for (final doDia in porDia.values) {
      doDia.sort(_comparar);
    }
    return porDia;
  }

  bool _dentroDoPeriodo(DateTime data, DateTime start, DateTime end) => !data.isBefore(start) && data.isBefore(end);

  int _comparar(AgendaItem a, AgendaItem b) {
    if (a.horario == null && b.horario == null) return a.title.compareTo(b.title);
    if (a.horario == null) return -1;
    if (b.horario == null) return 1;
    return a.horario!.compareTo(b.horario!);
  }
}

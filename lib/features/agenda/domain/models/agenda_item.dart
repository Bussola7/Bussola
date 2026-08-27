import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';

enum AgendaItemType { tarefa, evento }

/// Item unificado da visão "Lista" da Agenda: representa uma tarefa ou um
/// evento o bastante para ordenar e exibir os dois juntos, por dia e
/// horário. Não substitui [TaskModel]/[EventModel] — quem precisar dos
/// dados completos (para editar, por exemplo) usa [task]/[event].
class AgendaItem {
  final AgendaItemType type;
  final String id;
  final String title;

  /// Dia (sem hora) usado para agrupar o item na lista.
  final DateTime data;

  /// Horário exato, já convertido para o fuso local — nulo quando o item
  /// não tem hora específica (tarefa, ou evento de dia inteiro). Itens sem
  /// horário aparecem antes dos com horário, dentro do mesmo dia.
  final DateTime? horario;

  /// Tarefa concluída ou evento cancelado — mesmo tratamento visual
  /// (riscado/esmaecido) nos dois casos.
  final bool finalizado;

  final TaskModel? task;
  final EventModel? event;

  const AgendaItem._({
    required this.type,
    required this.id,
    required this.title,
    required this.data,
    this.horario,
    required this.finalizado,
    this.task,
    this.event,
  });

  /// [task.dueDate] precisa estar preenchido — quem monta a lista já filtra
  /// tarefas sem prazo antes de chamar isto (não têm dia para entrar aqui).
  factory AgendaItem.fromTask(TaskModel task) {
    final dueDate = task.dueDate!;
    return AgendaItem._(
      type: AgendaItemType.tarefa,
      id: task.id,
      title: task.title,
      data: DateTime(dueDate.year, dueDate.month, dueDate.day),
      finalizado: task.isConcluida,
      task: task,
    );
  }

  factory AgendaItem.fromEvent(EventModel event) {
    final inicio = event.startDatetime.toLocal();
    return AgendaItem._(
      type: AgendaItemType.evento,
      id: event.id,
      title: event.title,
      data: DateTime(inicio.year, inicio.month, inicio.day),
      horario: event.allDay ? null : inicio,
      finalizado: event.status == EventStatus.cancelado,
      event: event,
    );
  }

  String get etiqueta => type == AgendaItemType.tarefa ? 'Tarefa' : 'Horário';
}

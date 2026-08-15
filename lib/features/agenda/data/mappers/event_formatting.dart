import 'package:bussola/features/agenda/data/models/event_model.dart';

/// Formatação de horário/duração de um evento — antes duplicada entre
/// `EventCard` e `EventDetailSheet`; centralizada aqui na revisão de
/// arquitetura da Etapa 2.4.
class EventFormatting {
  EventFormatting._();

  static String horario(EventModel event) {
    if (event.allDay) return 'Dia inteiro';
    String hh(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${hh(event.startDatetime)} – ${hh(event.endDatetime)}';
  }

  static String duracao(EventModel event) {
    if (event.allDay) return '';
    final minutos = event.endDatetime.difference(event.startDatetime).inMinutes;
    if (minutos < 60) return '$minutos min';
    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    return resto == 0 ? '${horas}h' : '${horas}h${resto}min';
  }
}

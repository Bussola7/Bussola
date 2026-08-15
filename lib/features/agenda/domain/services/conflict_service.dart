import 'package:bussola/features/agenda/data/models/event_model.dart';

/// Verifica conflitos de horário. Não decide nada sozinho — só calcula
/// quais eventos colidem, para a UI avisar e deixar a pessoa escolher
/// entre continuar ou cancelar (nunca bloqueia automaticamente).
class ConflictService {
  /// Eventos de dia inteiro não entram na checagem: não têm um horário
  /// específico para "colidir" com outro, e travar a criação de vários
  /// eventos de dia inteiro no mesmo dia não agregaria valor real.
  List<EventModel> findConflicts({
    required DateTime candidateStart,
    required DateTime candidateEnd,
    required bool candidateAllDay,
    required List<EventModel> existingEvents,
    String? ignoreEventId,
  }) {
    if (candidateAllDay) return const [];

    return existingEvents.where((evento) {
      if (evento.id == ignoreEventId) return false;
      if (evento.allDay) return false;
      if (evento.isDeleted) return false;
      return _overlaps(candidateStart, candidateEnd, evento.startDatetime, evento.endDatetime);
    }).toList();
  }

  bool _overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }
}

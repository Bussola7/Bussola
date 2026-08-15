import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/data/repositories/event_repository.dart';

/// Regras de negócio de eventos. Nesta etapa cobre apenas validações
/// básicas de criação/edição e a exclusão (sempre soft delete) — detecção
/// de conflito de horário, cálculo de recorrência, lembretes e Radar
/// entram em etapas futuras (cada um com seu próprio Service, para não
/// inchar esta classe).
class EventService {
  final EventRepository _repository;

  EventService({EventRepository? repository}) : _repository = repository ?? EventRepository();

  Future<List<EventModel>> getEventsForPeriod({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) {
    return _repository.getByPeriod(userId: userId, start: start, end: end);
  }

  Future<EventModel> createEvent(EventModel event) {
    _validate(event);
    return _repository.create(event);
  }

  Future<EventModel> updateEvent(EventModel event, {String? updatedByUserId}) {
    _validate(event);
    return _repository.update(event, updatedByUserId: updatedByUserId);
  }

  /// Exclusão sempre "suave": o evento some das listagens normais, mas
  /// continua no banco (para futuro histórico/desfazer).
  Future<void> deleteEvent(String id, {required String deletedBy}) => _repository.delete(id, deletedBy: deletedBy);

  Future<void> restoreEvent(String id) => _repository.restore(id);

  void _validate(EventModel event) {
    if (event.title.trim().isEmpty) {
      throw ArgumentError('O evento precisa de um título.');
    }
    if (event.endDatetime.isBefore(event.startDatetime)) {
      throw ArgumentError('O horário final não pode ser antes do horário inicial.');
    }
  }
}

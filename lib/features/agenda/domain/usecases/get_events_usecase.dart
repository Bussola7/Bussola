import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/services/event_service.dart';

/// Caso de uso "Buscar Eventos". Devolve os [EventModel] completos (não
/// [EventEntity]) porque a UI de listagem (EventCard) precisa de campos
/// que o editor não expõe ainda, como prioridade e cor.
class GetEventsUseCase {
  final EventService _service;

  GetEventsUseCase({EventService? service}) : _service = service ?? EventService();

  Future<List<EventModel>> execute({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) {
    return _service.getEventsForPeriod(userId: userId, start: start, end: end);
  }
}

import 'package:bussola/features/agenda/data/mappers/event_mapper.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/entities/event_entity.dart';
import 'package:bussola/features/agenda/domain/services/event_service.dart';

/// Caso de uso "Criar Evento". A UI só chama `execute(...)` — nunca fala
/// com o [EventService], o Repository ou o Data Source diretamente.
class CreateEventUseCase {
  final EventService _service;

  CreateEventUseCase({EventService? service}) : _service = service ?? EventService();

  Future<EventEntity> execute({
    required EventEntity entity,
    required String calendarId,
    required String userId,
  }) async {
    final EventModel novoModel = EventMapper.toNewModel(entity: entity, calendarId: calendarId, userId: userId);
    final EventModel criado = await _service.createEvent(novoModel);
    return EventMapper.toEntity(criado);
  }
}

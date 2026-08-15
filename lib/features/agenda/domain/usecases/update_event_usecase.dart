import 'package:bussola/features/agenda/data/mappers/event_mapper.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/entities/event_entity.dart';
import 'package:bussola/features/agenda/domain/services/event_service.dart';

/// Caso de uso "Atualizar Evento". Recebe o [EventModel] atual (com todos
/// os campos, inclusive os que o editor não mexe) e a [EventEntity] com
/// as mudanças feitas na tela.
class UpdateEventUseCase {
  final EventService _service;

  UpdateEventUseCase({EventService? service}) : _service = service ?? EventService();

  Future<EventEntity> execute({
    required EventModel current,
    required EventEntity changes,
    required String updatedByUserId,
  }) async {
    final EventModel atualizado = EventMapper.applyChanges(current: current, entity: changes);
    final EventModel salvo = await _service.updateEvent(atualizado, updatedByUserId: updatedByUserId);
    return EventMapper.toEntity(salvo);
  }
}

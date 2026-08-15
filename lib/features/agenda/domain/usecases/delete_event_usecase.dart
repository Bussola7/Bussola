import 'package:bussola/features/agenda/domain/services/event_service.dart';

/// Caso de uso "Excluir Evento". Sempre soft delete — o [EventService]
/// (Etapa 1) já garante isso, este Use Case só expõe a ação para a UI.
class DeleteEventUseCase {
  final EventService _service;

  DeleteEventUseCase({EventService? service}) : _service = service ?? EventService();

  Future<void> execute({required String eventId, required String deletedByUserId}) {
    return _service.deleteEvent(eventId, deletedBy: deletedByUserId);
  }
}

import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/services/conflict_service.dart';
import 'package:bussola/features/agenda/domain/usecases/get_events_usecase.dart';

/// Verifica se um evento (novo ou editado) colide com outros já
/// existentes no mesmo dia. A UI decide o que fazer com o resultado —
/// este Use Case nunca bloqueia nada sozinho.
class CheckEventConflictsUseCase {
  final GetEventsUseCase _getEvents;
  final ConflictService _conflictService;

  CheckEventConflictsUseCase({GetEventsUseCase? getEvents, ConflictService? conflictService})
      : _getEvents = getEvents ?? GetEventsUseCase(),
        _conflictService = conflictService ?? ConflictService();

  Future<List<EventModel>> execute({
    required String userId,
    required DateTime candidateStart,
    required DateTime candidateEnd,
    required bool candidateAllDay,
    String? ignoreEventId,
  }) async {
    final inicioDoDia = DateTime(candidateStart.year, candidateStart.month, candidateStart.day);
    final fimDoDia = inicioDoDia.add(const Duration(days: 1));
    final eventosDoDia = await _getEvents.execute(userId: userId, start: inicioDoDia, end: fimDoDia);

    return _conflictService.findConflicts(
      candidateStart: candidateStart,
      candidateEnd: candidateEnd,
      candidateAllDay: candidateAllDay,
      existingEvents: eventosDoDia,
      ignoreEventId: ignoreEventId,
    );
  }
}

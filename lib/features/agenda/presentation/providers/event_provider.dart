import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/data/models/reminder_model.dart';
import 'package:bussola/features/agenda/domain/entities/event_entity.dart';
import 'package:bussola/features/agenda/domain/usecases/create_event_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/delete_event_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/get_event_reminders_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/get_events_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/set_event_reminders_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/update_event_usecase.dart';

/// Estado dos eventos do período visível. A tela só enxerga isto — quem
/// carrega, cria, atualiza e exclui é sempre este Notifier, através dos
/// Use Cases (nunca falando com Repository ou Data Source diretamente).
class EventListState {
  final List<EventModel> events;
  final bool isLoading;
  final String? errorMessage;

  const EventListState({this.events = const [], this.isLoading = false, this.errorMessage});

  EventListState copyWith({List<EventModel>? events, bool? isLoading, String? errorMessage}) {
    return EventListState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class EventNotifier extends StateNotifier<EventListState> {
  final GetEventsUseCase _getEvents;
  final CreateEventUseCase _createEvent;
  final UpdateEventUseCase _updateEvent;
  final DeleteEventUseCase _deleteEvent;
  final SetEventRemindersUseCase _setReminders;

  String? _userId;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  EventNotifier({
    GetEventsUseCase? getEvents,
    CreateEventUseCase? createEvent,
    UpdateEventUseCase? updateEvent,
    DeleteEventUseCase? deleteEvent,
    SetEventRemindersUseCase? setReminders,
  })  : _getEvents = getEvents ?? GetEventsUseCase(),
        _createEvent = createEvent ?? CreateEventUseCase(),
        _updateEvent = updateEvent ?? UpdateEventUseCase(),
        _deleteEvent = deleteEvent ?? DeleteEventUseCase(),
        _setReminders = setReminders ?? SetEventRemindersUseCase(),
        super(const EventListState());

  Future<void> loadPeriod({required String userId, required DateTime start, required DateTime end}) async {
    _userId = userId;
    _rangeStart = start;
    _rangeEnd = end;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final events = await _getEvents.execute(userId: userId, start: start, end: end);
      state = state.copyWith(events: events, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Não foi possível carregar os eventos.');
    }
  }

  /// Recarrega o mesmo período já carregado — usado depois de criar,
  /// editar ou excluir. Falha de refresh não derruba o que já estava na tela.
  Future<void> _refresh() async {
    if (_userId == null || _rangeStart == null || _rangeEnd == null) return;
    try {
      final events = await _getEvents.execute(userId: _userId!, start: _rangeStart!, end: _rangeEnd!);
      state = state.copyWith(events: events);
    } catch (_) {}
  }

  /// Cria o evento e, em seguida, salva os lembretes escolhidos na tela —
  /// duas ações, dois Use Cases, orquestrados aqui (é papel do Notifier,
  /// não de um Use Case chamar o outro por baixo dos panos).
  Future<bool> createEvent({
    required EventEntity entity,
    required String calendarId,
    required String userId,
    List<ReminderModel> reminders = const [],
  }) async {
    try {
      final criado = await _createEvent.execute(entity: entity, calendarId: calendarId, userId: userId);
      if (reminders.isNotEmpty && criado.id != null) {
        await _setReminders.execute(criado.id!, reminders);
      }
      await _refresh();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Não foi possível criar o evento.');
      return false;
    }
  }

  Future<bool> updateEvent({
    required EventModel current,
    required EventEntity changes,
    required String updatedByUserId,
    List<ReminderModel> reminders = const [],
  }) async {
    try {
      await _updateEvent.execute(current: current, changes: changes, updatedByUserId: updatedByUserId);
      await _setReminders.execute(current.id, reminders);
      await _refresh();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Não foi possível atualizar o evento.');
      return false;
    }
  }

  Future<bool> deleteEvent({required String eventId, required String deletedByUserId}) async {
    try {
      await _deleteEvent.execute(eventId: eventId, deletedByUserId: deletedByUserId);
      state = state.copyWith(events: state.events.where((e) => e.id != eventId).toList());
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Não foi possível excluir o evento.');
      return false;
    }
  }
}

final eventNotifierProvider = StateNotifierProvider<EventNotifier, EventListState>(
  (ref) => EventNotifier(),
);

/// Lembretes de um evento específico. `family` porque cada evento tem sua
/// própria lista — usado pelo `EventDetailSheet` e pelo `EventEditor`.
final eventRemindersProvider = FutureProvider.family<List<ReminderModel>, String>((ref, eventId) {
  return GetEventRemindersUseCase().execute(eventId);
});

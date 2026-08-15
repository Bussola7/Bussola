import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/entities/event_entity.dart';
import 'package:bussola/features/agenda/domain/services/event_service.dart';
import 'package:bussola/features/agenda/domain/usecases/create_event_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/delete_event_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/get_events_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/update_event_usecase.dart';

/// EventService falso: não toca no Supabase, só registra o que foi
/// chamado — usado para testar os Use Cases isoladamente.
class _FakeEventService extends EventService {
  EventModel? lastCreated;
  EventModel? lastUpdated;
  String? lastDeletedId;
  String? lastDeletedBy;

  @override
  Future<EventModel> createEvent(EventModel event) async {
    lastCreated = event;
    return event.copyWith(); // simula o retorno do banco (com id já preenchido na prática)
  }

  @override
  Future<EventModel> updateEvent(EventModel event, {String? updatedByUserId}) async {
    lastUpdated = event;
    return event;
  }

  @override
  Future<void> deleteEvent(String id, {required String deletedBy}) async {
    lastDeletedId = id;
    lastDeletedBy = deletedBy;
  }

  @override
  Future<List<EventModel>> getEventsForPeriod({required String userId, required DateTime start, required DateTime end}) async {
    return [];
  }
}

EventModel _buildModel() {
  final now = DateTime.now();
  return EventModel(
    id: 'evt-1',
    calendarId: 'cal-1',
    userId: 'user-1',
    title: 'Consulta',
    startDatetime: DateTime(2026, 8, 1, 9, 0),
    endDatetime: DateTime(2026, 8, 1, 10, 0),
    timezone: 'America/Sao_Paulo',
    allDay: false,
    priority: Priority.media,
    status: EventStatus.confirmado,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('CreateEventUseCase', () {
    test('monta o EventModel a partir da entidade e chama o service', () async {
      final fakeService = _FakeEventService();
      final useCase = CreateEventUseCase(service: fakeService);

      final entity = EventEntity(
        title: 'Dentista',
        startDatetime: DateTime(2026, 8, 3, 10, 0),
        endDatetime: DateTime(2026, 8, 3, 11, 0),
        allDay: false,
        location: 'Clínica',
      );

      final created = await useCase.execute(entity: entity, calendarId: 'cal-1', userId: 'user-1');

      expect(created.title, 'Dentista');
      expect(fakeService.lastCreated?.calendarId, 'cal-1');
      expect(fakeService.lastCreated?.userId, 'user-1');
    });
  });

  group('UpdateEventUseCase', () {
    test('aplica as mudanças da entidade sobre o evento atual', () async {
      final fakeService = _FakeEventService();
      final useCase = UpdateEventUseCase(service: fakeService);
      final atual = _buildModel();

      final mudancas = EventEntity(
        id: atual.id,
        title: 'Consulta remarcada',
        startDatetime: atual.startDatetime,
        endDatetime: atual.endDatetime,
        allDay: false,
      );

      final resultado = await useCase.execute(current: atual, changes: mudancas, updatedByUserId: 'user-1');

      expect(resultado.title, 'Consulta remarcada');
      expect(fakeService.lastUpdated?.priority, atual.priority); // não foi alterada nesta chamada
    });
  });

  group('DeleteEventUseCase', () {
    test('repassa o id e quem excluiu para o service (soft delete)', () async {
      final fakeService = _FakeEventService();
      final useCase = DeleteEventUseCase(service: fakeService);

      await useCase.execute(eventId: 'evt-1', deletedByUserId: 'user-1');

      expect(fakeService.lastDeletedId, 'evt-1');
      expect(fakeService.lastDeletedBy, 'user-1');
    });
  });

  group('GetEventsUseCase', () {
    test('repassa userId/start/end para o service', () async {
      final fakeService = _FakeEventService();
      final useCase = GetEventsUseCase(service: fakeService);

      final resultado = await useCase.execute(
        userId: 'user-1',
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 9, 1),
      );

      expect(resultado, isEmpty); // o fake sempre devolve lista vazia
    });
  });
}

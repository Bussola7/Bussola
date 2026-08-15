import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/data/repositories/event_repository.dart';
import 'package:bussola/features/agenda/domain/services/event_service.dart';

/// Repositório falso: não toca no Supabase, só simula "salvar" devolvendo
/// o próprio evento recebido. Usado para testar as regras do EventService
/// isoladamente da camada de dados.
class _FakeEventRepository extends EventRepository {
  @override
  Future<EventModel> create(EventModel event) async => event;

  @override
  Future<EventModel> update(EventModel event, {String? updatedByUserId}) async => event;

  @override
  Future<void> delete(String id, {required String deletedBy}) async {}
}

EventModel _buildEvent({required DateTime start, required DateTime end, String title = 'Reunião'}) {
  return EventModel(
    id: 'evt-1',
    calendarId: 'cal-1',
    userId: 'user-1',
    title: title,
    startDatetime: start,
    endDatetime: end,
    timezone: 'America/Sao_Paulo',
    allDay: false,
    priority: Priority.media,
    status: EventStatus.confirmado,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late EventService service;

  setUp(() {
    service = EventService(repository: _FakeEventRepository());
  });

  group('EventService.createEvent', () {
    test('cria evento válido normalmente', () async {
      final start = DateTime(2026, 8, 1, 9, 0);
      final end = DateTime(2026, 8, 1, 10, 0);

      final created = await service.createEvent(_buildEvent(start: start, end: end));

      expect(created.title, 'Reunião');
    });

    test('rejeita evento com título vazio', () async {
      final start = DateTime(2026, 8, 1, 9, 0);
      final end = DateTime(2026, 8, 1, 10, 0);

      expect(
        () => service.createEvent(_buildEvent(start: start, end: end, title: '   ')),
        throwsArgumentError,
      );
    });

    test('rejeita evento cujo horário final é antes do inicial', () async {
      final start = DateTime(2026, 8, 1, 10, 0);
      final end = DateTime(2026, 8, 1, 9, 0);

      expect(
        () => service.createEvent(_buildEvent(start: start, end: end)),
        throwsArgumentError,
      );
    });
  });

  group('EventService.deleteEvent', () {
    test('soft delete não lança erro e recebe quem excluiu', () async {
      final start = DateTime(2026, 8, 1, 9, 0);
      final end = DateTime(2026, 8, 1, 10, 0);
      await service.createEvent(_buildEvent(start: start, end: end));

      await expectLater(
        service.deleteEvent('evt-1', deletedBy: 'user-1'),
        completes,
      );
    });
  });
}

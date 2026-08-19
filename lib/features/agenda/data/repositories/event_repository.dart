import 'package:bussola/features/agenda/data/datasources/event_datasource.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/data/models/participant_model.dart';
import 'package:bussola/features/agenda/data/models/reminder_model.dart';

/// Converte entre JSON cru (do datasource) e os models de evento,
/// lembrete e participante. Não contém regra de negócio.
class EventRepository {
  final EventDataSource _dataSource;

  EventRepository({EventDataSource? dataSource}) : _dataSource = dataSource ?? EventDataSource();

  Future<List<EventModel>> getByPeriod({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _dataSource.fetchByPeriod(userId: userId, start: start, end: end);
    return rows.map(EventModel.fromJson).toList();
  }

  Future<List<EventModel>> getDeleted(String userId) async {
    final rows = await _dataSource.fetchDeleted(userId);
    return rows.map(EventModel.fromJson).toList();
  }

  Future<EventModel?> getById(String id) async {
    final row = await _dataSource.fetchById(id);
    return row == null ? null : EventModel.fromJson(row);
  }

  Future<List<EventModel>> getAllActive(String userId) async {
    final rows = await _dataSource.fetchAllActive(userId);
    return rows.map(EventModel.fromJson).toList();
  }

  Future<EventModel> create(EventModel event) async {
    final row = await _dataSource.insertEvent(event.toInsertJson(userId: event.userId));
    return EventModel.fromJson(row);
  }

  Future<EventModel> update(EventModel event, {String? updatedByUserId}) async {
    final row = await _dataSource.updateEvent(event.id, event.toUpdateJson(updatedByUserId: updatedByUserId));
    return EventModel.fromJson(row);
  }

  /// Exclusão nesta camada é sempre soft delete — nunca apaga a linha.
  Future<void> delete(String id, {required String deletedBy}) => _dataSource.softDeleteEvent(id, deletedBy: deletedBy);

  Future<void> restore(String id) => _dataSource.restoreEvent(id);

  Future<int> countByCategory({required String userId, required String categoryId}) {
    return _dataSource.countByCategory(userId: userId, categoryId: categoryId);
  }

  Future<void> reassignCategory({required String userId, required String fromCategoryId, required String toCategoryId}) {
    return _dataSource.reassignCategory(userId: userId, fromCategoryId: fromCategoryId, toCategoryId: toCategoryId);
  }

  Future<List<ReminderModel>> getReminders(String eventId) async {
    final rows = await _dataSource.fetchReminders(eventId);
    return rows.map(ReminderModel.fromJson).toList();
  }

  Future<ReminderModel> addReminder(String eventId, ReminderModel reminder) async {
    final row = await _dataSource.insertReminder(reminder.toInsertJson(eventId: eventId));
    return ReminderModel.fromJson(row);
  }

  Future<void> removeReminder(String id) => _dataSource.deleteReminder(id);

  Future<List<ParticipantModel>> getParticipants(String eventId) async {
    final rows = await _dataSource.fetchParticipants(eventId);
    return rows.map(ParticipantModel.fromJson).toList();
  }

  Future<ParticipantModel> addParticipant(String eventId, ParticipantModel participant) async {
    final row = await _dataSource.insertParticipant(participant.toInsertJson(eventId: eventId));
    return ParticipantModel.fromJson(row);
  }

  Future<void> removeParticipant(String id) => _dataSource.deleteParticipant(id);
}

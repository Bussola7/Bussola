import 'package:bussola/features/agenda/data/models/reminder_model.dart';
import 'package:bussola/features/agenda/domain/services/reminder_service.dart';

class GetEventRemindersUseCase {
  final ReminderService _service;

  GetEventRemindersUseCase({ReminderService? service}) : _service = service ?? ReminderService();

  Future<List<ReminderModel>> execute(String eventId) => _service.getReminders(eventId);
}

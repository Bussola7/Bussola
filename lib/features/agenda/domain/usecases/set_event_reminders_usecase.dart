import 'package:bussola/features/agenda/data/models/reminder_model.dart';
import 'package:bussola/features/agenda/domain/services/reminder_service.dart';

class SetEventRemindersUseCase {
  final ReminderService _service;

  SetEventRemindersUseCase({ReminderService? service}) : _service = service ?? ReminderService();

  Future<List<ReminderModel>> execute(String eventId, List<ReminderModel> reminders) {
    return _service.setReminders(eventId, reminders);
  }
}

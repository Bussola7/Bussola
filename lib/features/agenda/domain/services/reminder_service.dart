import 'package:bussola/features/agenda/data/models/reminder_model.dart';
import 'package:bussola/features/agenda/data/repositories/event_repository.dart';

/// Regras de negócio dos lembretes. Nesta etapa só permite salvar/editar
/// — nenhuma notificação local ou push é disparada a partir daqui.
class ReminderService {
  final EventRepository _repository;

  ReminderService({EventRepository? repository}) : _repository = repository ?? EventRepository();

  Future<List<ReminderModel>> getReminders(String eventId) => _repository.getReminders(eventId);

  /// Substitui TODOS os lembretes de um evento pela lista informada.
  /// Mais simples e seguro do que calcular um "diff" entre o que existia
  /// e o que foi escolhido de novo na tela — e como lembretes não têm
  /// nenhum estado próprio (não foram "disparados" ainda, nesta etapa),
  /// não há nada de valor em preservar os registros antigos.
  Future<List<ReminderModel>> setReminders(String eventId, List<ReminderModel> reminders) async {
    final atuais = await _repository.getReminders(eventId);
    for (final atual in atuais) {
      await _repository.removeReminder(atual.id);
    }

    final salvos = <ReminderModel>[];
    for (final novo in reminders) {
      if (novo.type.name == 'personalizado' && novo.minutesBefore <= 0) {
        throw ArgumentError('Um lembrete personalizado precisa de um tempo maior que zero.');
      }
      salvos.add(await _repository.addReminder(eventId, novo));
    }
    return salvos;
  }
}

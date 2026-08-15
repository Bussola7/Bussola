import 'package:bussola/features/agenda/data/models/calendar_model.dart';
import 'package:bussola/features/agenda/data/repositories/calendar_repository.dart';

/// Regras de negócio de calendários. Nesta etapa é simples (cada usuário
/// tem um calendário padrão), mas já isolado do Repository para crescer
/// sem impactar a camada de dados.
class CalendarService {
  final CalendarRepository _repository;

  CalendarService({CalendarRepository? repository}) : _repository = repository ?? CalendarRepository();

  Future<List<CalendarModel>> listCalendars(String userId) => _repository.getAll(userId);

  Future<CalendarModel?> getDefaultCalendar(String userId) async {
    final calendars = await _repository.getAll(userId);
    if (calendars.isEmpty) return null;
    return calendars.firstWhere((c) => c.isDefault, orElse: () => calendars.first);
  }

  Future<CalendarModel> createCalendar({
    required String userId,
    required String name,
    required String color,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('O nome do calendário não pode ser vazio.');
    }
    final now = DateTime.now();
    return _repository.create(CalendarModel(
      id: '',
      userId: userId,
      name: name.trim(),
      color: color,
      isDefault: false,
      createdAt: now,
      updatedAt: now,
    ));
  }
}

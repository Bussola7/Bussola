import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/reminder_model.dart';
import 'package:bussola/features/agenda/data/repositories/event_repository.dart';
import 'package:bussola/features/agenda/domain/services/reminder_service.dart';

ReminderModel _buildReminder({required String id, required ReminderType type, int minutes = 0}) {
  return ReminderModel(id: id, eventId: 'evt-1', minutesBefore: minutes, type: type, createdAt: DateTime.now());
}

/// EventRepository falso: guarda os lembretes "salvos" em memória, para
/// testar a lógica de substituição do ReminderService sem Supabase.
class _FakeEventRepository extends EventRepository {
  final List<ReminderModel> existentes;
  final List<String> removidos = [];
  final List<ReminderModel> adicionados = [];

  _FakeEventRepository(this.existentes);

  @override
  Future<List<ReminderModel>> getReminders(String eventId) async => existentes;

  @override
  Future<void> removeReminder(String id) async => removidos.add(id);

  @override
  Future<ReminderModel> addReminder(String eventId, ReminderModel reminder) async {
    adicionados.add(reminder);
    return reminder;
  }
}

void main() {
  group('ReminderService.setReminders', () {
    test('remove todos os lembretes antigos e adiciona os novos (substituição completa)', () async {
      final antigos = [_buildReminder(id: 'r1', type: ReminderType.min15, minutes: 15)];
      final fakeRepo = _FakeEventRepository(antigos);
      final service = ReminderService(repository: fakeRepo);

      final novos = [
        _buildReminder(id: '', type: ReminderType.noHorario, minutes: 0),
        _buildReminder(id: '', type: ReminderType.hora1, minutes: 60),
      ];

      await service.setReminders('evt-1', novos);

      expect(fakeRepo.removidos, ['r1']);
      expect(fakeRepo.adicionados.length, 2);
    });

    test('rejeita lembrete personalizado com 0 ou menos minutos', () async {
      final fakeRepo = _FakeEventRepository([]);
      final service = ReminderService(repository: fakeRepo);

      final invalido = [_buildReminder(id: '', type: ReminderType.personalizado, minutes: 0)];

      expect(() => service.setReminders('evt-1', invalido), throwsArgumentError);
    });

    test('aceita lembrete personalizado com minutos válidos', () async {
      final fakeRepo = _FakeEventRepository([]);
      final service = ReminderService(repository: fakeRepo);

      final valido = [_buildReminder(id: '', type: ReminderType.personalizado, minutes: 45)];

      await service.setReminders('evt-1', valido);

      expect(fakeRepo.adicionados.single.minutesBefore, 45);
    });
  });
}

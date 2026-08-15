import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/services/conflict_service.dart';

EventModel _buildEvent({
  required String id,
  required DateTime start,
  required DateTime end,
  bool allDay = false,
  DateTime? deletedAt,
}) {
  final now = DateTime.now();
  return EventModel(
    id: id,
    calendarId: 'cal-1',
    userId: 'user-1',
    title: 'Evento $id',
    startDatetime: start,
    endDatetime: end,
    timezone: 'America/Sao_Paulo',
    allDay: allDay,
    deletedAt: deletedAt,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final service = ConflictService();

  test('eventos sem conflito (horários bem separados) não geram nenhum resultado', () {
    final existentes = [_buildEvent(id: 'a', start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 10))];

    final conflitos = service.findConflicts(
      candidateStart: DateTime(2026, 1, 1, 14),
      candidateEnd: DateTime(2026, 1, 1, 15),
      candidateAllDay: false,
      existingEvents: existentes,
    );

    expect(conflitos, isEmpty);
  });

  test('conflito parcial (sobreposição de parte do horário) é detectado', () {
    final existentes = [_buildEvent(id: 'a', start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 11))];

    final conflitos = service.findConflicts(
      candidateStart: DateTime(2026, 1, 1, 10),
      candidateEnd: DateTime(2026, 1, 1, 12),
      candidateAllDay: false,
      existingEvents: existentes,
    );

    expect(conflitos.length, 1);
  });

  test('conflito total (um evento contido dentro do outro) é detectado', () {
    final existentes = [_buildEvent(id: 'a', start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 12))];

    final conflitos = service.findConflicts(
      candidateStart: DateTime(2026, 1, 1, 10),
      candidateEnd: DateTime(2026, 1, 1, 11),
      candidateAllDay: false,
      existingEvents: existentes,
    );

    expect(conflitos.length, 1);
  });

  test('eventos exatamente no mesmo horário são detectados como conflito', () {
    final existentes = [_buildEvent(id: 'a', start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 10))];

    final conflitos = service.findConflicts(
      candidateStart: DateTime(2026, 1, 1, 9),
      candidateEnd: DateTime(2026, 1, 1, 10),
      candidateAllDay: false,
      existingEvents: existentes,
    );

    expect(conflitos.length, 1);
  });

  test('eventos consecutivos (um termina exatamente quando o outro começa) NÃO é conflito', () {
    final existentes = [_buildEvent(id: 'a', start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 10))];

    final conflitos = service.findConflicts(
      candidateStart: DateTime(2026, 1, 1, 10), // começa exatamente quando "a" termina
      candidateEnd: DateTime(2026, 1, 1, 11),
      candidateAllDay: false,
      existingEvents: existentes,
    );

    expect(conflitos, isEmpty);
  });

  test('o evento que começa quando o candidato termina também NÃO é conflito (checagem simétrica)', () {
    final existentes = [_buildEvent(id: 'a', start: DateTime(2026, 1, 1, 11), end: DateTime(2026, 1, 1, 12))];

    final conflitos = service.findConflicts(
      candidateStart: DateTime(2026, 1, 1, 10),
      candidateEnd: DateTime(2026, 1, 1, 11), // termina exatamente quando "a" começa
      candidateAllDay: false,
      existingEvents: existentes,
    );

    expect(conflitos, isEmpty);
  });

  test('candidato de dia inteiro nunca gera conflito (não tem horário específico)', () {
    final existentes = [_buildEvent(id: 'a', start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 10))];

    final conflitos = service.findConflicts(
      candidateStart: DateTime(2026, 1, 1),
      candidateEnd: DateTime(2026, 1, 1, 23, 59),
      candidateAllDay: true,
      existingEvents: existentes,
    );

    expect(conflitos, isEmpty);
  });

  test('evento de dia inteiro na lista de existentes é ignorado na checagem', () {
    final existentes = [_buildEvent(id: 'a', start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 1, 23, 59), allDay: true)];

    final conflitos = service.findConflicts(
      candidateStart: DateTime(2026, 1, 1, 9),
      candidateEnd: DateTime(2026, 1, 1, 10),
      candidateAllDay: false,
      existingEvents: existentes,
    );

    expect(conflitos, isEmpty);
  });

  test('evento excluído (soft delete) é ignorado na checagem', () {
    final existentes = [
      _buildEvent(
        id: 'a',
        start: DateTime(2026, 1, 1, 9),
        end: DateTime(2026, 1, 1, 10),
        deletedAt: DateTime(2026, 1, 1),
      ),
    ];

    final conflitos = service.findConflicts(
      candidateStart: DateTime(2026, 1, 1, 9),
      candidateEnd: DateTime(2026, 1, 1, 10),
      candidateAllDay: false,
      existingEvents: existentes,
    );

    expect(conflitos, isEmpty);
  });

  test('ignoreEventId exclui o próprio evento da checagem (útil ao editar)', () {
    final existentes = [_buildEvent(id: 'evt-sendo-editado', start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 10))];

    final conflitos = service.findConflicts(
      candidateStart: DateTime(2026, 1, 1, 9),
      candidateEnd: DateTime(2026, 1, 1, 10),
      candidateAllDay: false,
      existingEvents: existentes,
      ignoreEventId: 'evt-sendo-editado',
    );

    expect(conflitos, isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/services/recurrence_service.dart';

EventModel _buildEvent({
  required DateTime start,
  required DateTime end,
  RecurrenceType type = RecurrenceType.nunca,
  DateTime? until,
  int? count,
}) {
  final now = DateTime.now();
  return EventModel(
    id: 'evt-1',
    calendarId: 'cal-1',
    userId: 'user-1',
    title: 'Evento',
    startDatetime: start,
    endDatetime: end,
    timezone: 'America/Sao_Paulo',
    allDay: false,
    recurrenceType: type,
    recurrenceUntil: until,
    recurrenceCount: count,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final service = RecurrenceService();

  group('Evento sem recorrência', () {
    test('devolve 1 ocorrência quando o evento cai dentro do período', () {
      final evento = _buildEvent(start: DateTime(2026, 1, 10, 9), end: DateTime(2026, 1, 10, 10));

      final ocorrencias = service.occurrencesInRange(
        event: evento,
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 1, 31),
      );

      expect(ocorrencias.length, 1);
      expect(ocorrencias.first.start, evento.startDatetime);
    });

    test('devolve 0 ocorrências quando o evento cai fora do período', () {
      final evento = _buildEvent(start: DateTime(2026, 2, 10, 9), end: DateTime(2026, 2, 10, 10));

      final ocorrencias = service.occurrencesInRange(
        event: evento,
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 1, 31),
      );

      expect(ocorrencias, isEmpty);
    });
  });

  group('Recorrência diária', () {
    test('gera 1 ocorrência por dia dentro do período', () {
      final evento = _buildEvent(
        start: DateTime(2026, 1, 1, 9),
        end: DateTime(2026, 1, 1, 10),
        type: RecurrenceType.diario,
      );

      final ocorrencias = service.occurrencesInRange(
        event: evento,
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 1, 6), // 1,2,3,4,5 — 5 dias
      );

      expect(ocorrencias.length, 5);
      expect(ocorrencias.first.start, DateTime(2026, 1, 1, 9));
      expect(ocorrencias.last.start, DateTime(2026, 1, 5, 9));
    });
  });

  group('Recorrência semanal', () {
    test('gera 1 ocorrência a cada 7 dias', () {
      final evento = _buildEvent(
        start: DateTime(2026, 1, 1, 9),
        end: DateTime(2026, 1, 1, 10),
        type: RecurrenceType.semanal,
      );

      final ocorrencias = service.occurrencesInRange(
        event: evento,
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 1, 1, 9).add(const Duration(days: 22)), // 1, 8, 15, 22
      );

      expect(ocorrencias.length, 4);
      expect(ocorrencias[1].start, DateTime(2026, 1, 8, 9));
      expect(ocorrencias[3].start, DateTime(2026, 1, 22, 9));
    });
  });

  group('Recorrência quinzenal', () {
    test('gera 1 ocorrência a cada 14 dias', () {
      final evento = _buildEvent(
        start: DateTime(2026, 1, 1, 9),
        end: DateTime(2026, 1, 1, 10),
        type: RecurrenceType.quinzenal,
      );

      final ocorrencias = service.occurrencesInRange(
        event: evento,
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 1, 1, 9).add(const Duration(days: 29)), // 1, 15, 29
      );

      expect(ocorrencias.length, 3);
      expect(ocorrencias[1].start, DateTime(2026, 1, 15, 9));
      expect(ocorrencias[2].start, DateTime(2026, 1, 29, 9));
    });
  });

  group('Recorrência mensal', () {
    test('gera 1 ocorrência por mês, no mesmo dia', () {
      final evento = _buildEvent(
        start: DateTime(2026, 1, 15, 9),
        end: DateTime(2026, 1, 15, 10),
        type: RecurrenceType.mensal,
      );

      final ocorrencias = service.occurrencesInRange(
        event: evento,
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2026, 3, 16, 9), // Jan, Fev, Mar (dia 15 de cada um)
      );

      expect(ocorrencias.length, 3);
      expect(ocorrencias[1].start, DateTime(2026, 2, 15, 9));
      expect(ocorrencias[2].start, DateTime(2026, 3, 15, 9));
    });
  });

  group('Recorrência anual', () {
    test('gera 1 ocorrência por ano, na mesma data', () {
      final evento = _buildEvent(
        start: DateTime(2024, 6, 10, 9),
        end: DateTime(2024, 6, 10, 10),
        type: RecurrenceType.anual,
      );

      final ocorrencias = service.occurrencesInRange(
        event: evento,
        rangeStart: DateTime(2024, 1, 1),
        rangeEnd: DateTime(2026, 6, 11, 9), // 2024, 2025, 2026
      );

      expect(ocorrencias.length, 3);
      expect(ocorrencias[2].start, DateTime(2026, 6, 10, 9));
    });
  });

  group('Recorrência limitada por data (recurrenceUntil)', () {
    test('para de gerar ocorrências após a data limite, mesmo com período maior', () {
      final evento = _buildEvent(
        start: DateTime(2026, 1, 1, 9),
        end: DateTime(2026, 1, 1, 10),
        type: RecurrenceType.semanal,
        until: DateTime(2026, 1, 15, 9),
      );

      final ocorrencias = service.occurrencesInRange(
        event: evento,
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2027, 1, 1), // período bem maior que o limite
      );

      expect(ocorrencias.length, 3); // 1, 8, 15 — depois disso já passou de recurrenceUntil
    });
  });

  group('Recorrência limitada por quantidade (recurrenceCount)', () {
    test('para de gerar ocorrências após atingir o número máximo', () {
      final evento = _buildEvent(
        start: DateTime(2026, 1, 1, 9),
        end: DateTime(2026, 1, 1, 10),
        type: RecurrenceType.semanal,
        count: 3,
      );

      final ocorrencias = service.occurrencesInRange(
        event: evento,
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2027, 1, 1), // período bem maior que as 3 ocorrências
      );

      expect(ocorrencias.length, 3);
    });
  });

  group('Recorrência cancelada', () {
    test('cancelRecurrence volta o evento a ser único (RecurrenceType.nunca)', () {
      final recorrente = _buildEvent(
        start: DateTime(2026, 1, 1, 9),
        end: DateTime(2026, 1, 1, 10),
        type: RecurrenceType.semanal,
      );

      final cancelado = service.cancelRecurrence(recorrente);

      expect(cancelado.recurrenceType, RecurrenceType.nunca);
      expect(cancelado.isRecurring, false);

      // depois de cancelado, volta a se comportar como evento único
      final ocorrencias = service.occurrencesInRange(
        event: cancelado,
        rangeStart: DateTime(2026, 1, 1),
        rangeEnd: DateTime(2027, 1, 1),
      );
      expect(ocorrencias.length, 1);
    });
  });
}

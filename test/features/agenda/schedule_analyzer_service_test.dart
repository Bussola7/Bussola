import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/services/schedule_analyzer_service.dart';

EventModel _buildEvent({
  required String id,
  required DateTime start,
  required DateTime end,
  bool allDay = false,
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
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final service = ScheduleAnalyzerService();
  // Referência fixa para completedCount/pendingCount não depender do
  // relógio real da máquina que roda o teste.
  final referencia = DateTime(2026, 1, 1, 23, 0);

  group('Dia sem eventos', () {
    test('a janela inteira (07h–22h = 15h) conta como livre', () {
      final analise = service.analyze([], now: referencia);

      expect(analise.eventCount, 0);
      expect(analise.busyDuration, Duration.zero);
      expect(analise.freeDuration, const Duration(hours: 15));
      expect(analise.largestFreeInterval, const Duration(hours: 15));
      expect(analise.smallestFreeInterval, const Duration(hours: 15));
      expect(analise.focusBlocks.length, 1);
    });
  });

  group('Apenas um evento', () {
    test('calcula ocupado/livre corretamente ao redor de um único evento', () {
      final eventos = [_buildEvent(id: 'a', start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 10))];

      final analise = service.analyze(eventos, now: referencia);

      expect(analise.eventCount, 1);
      expect(analise.busyDuration, const Duration(hours: 1));
      expect(analise.freeDuration, const Duration(hours: 14));
      expect(analise.largestFreeInterval, const Duration(hours: 12)); // 10h–22h
      expect(analise.smallestFreeInterval, const Duration(hours: 2)); // 7h–9h
      expect(analise.focusBlocks.length, 2);
      expect(analise.completedCount, 1); // evento termina antes da referência (23h)
      expect(analise.pendingCount, 0);
    });
  });

  group('Múltiplos eventos', () {
    test('calcula corretamente com 2 eventos separados por um intervalo', () {
      final eventos = [
        _buildEvent(id: 'a', start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 10)),
        _buildEvent(id: 'b', start: DateTime(2026, 1, 1, 14), end: DateTime(2026, 1, 1, 15)),
      ];

      final analise = service.analyze(eventos, now: referencia);

      expect(analise.eventCount, 2);
      expect(analise.busyDuration, const Duration(hours: 2));
      expect(analise.freeDuration, const Duration(hours: 13));
      expect(analise.largestFreeInterval, const Duration(hours: 7)); // 15h–22h
      expect(analise.smallestFreeInterval, const Duration(hours: 2)); // 7h–9h
      expect(analise.focusBlocks.length, 3); // 7-9, 10-14, 15-22
    });
  });

  group('Eventos consecutivos (sem intervalo entre eles)', () {
    test('não gera nenhum intervalo livre entre dois eventos encostados', () {
      final eventos = [
        _buildEvent(id: 'a', start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 10)),
        _buildEvent(id: 'b', start: DateTime(2026, 1, 1, 10), end: DateTime(2026, 1, 1, 11)),
      ];

      final analise = service.analyze(eventos, now: referencia);

      expect(analise.busyDuration, const Duration(hours: 2));
      expect(analise.freeDuration, const Duration(hours: 13));
      // só os 2 intervalos das pontas (7h-9h e 11h-22h) — nenhum entre os eventos
      expect(analise.focusBlocks.length, 2);
      expect(analise.smallestFreeInterval, const Duration(hours: 2));
      expect(analise.largestFreeInterval, const Duration(hours: 11));
    });
  });

  group('Evento parcialmente fora da janela de análise', () {
    test('conta só a parte do evento que cai dentro da janela (07h–22h)', () {
      // Começa às 6h (fora da janela) e termina às 8h (dentro).
      final eventos = [_buildEvent(id: 'a', start: DateTime(2026, 1, 1, 6), end: DateTime(2026, 1, 1, 8))];

      final analise = service.analyze(eventos, now: referencia);

      expect(analise.busyDuration, const Duration(hours: 1)); // só 7h–8h conta
      expect(analise.freeDuration, const Duration(hours: 14));
      expect(analise.focusBlocks.length, 1); // só o intervalo 8h–22h
      expect(analise.largestFreeInterval, const Duration(hours: 14));
    });
  });

  group('Evento totalmente fora da janela de análise', () {
    test('REGRESSÃO: evento depois das 22h não "come" nenhum tempo livre', () {
      final eventos = [_buildEvent(id: 'a', start: DateTime(2026, 1, 1, 23), end: DateTime(2026, 1, 1, 23, 30))];

      final analise = service.analyze(eventos, now: referencia);

      expect(analise.eventCount, 1); // ele existe, só não afeta a janela de análise
      expect(analise.busyDuration, Duration.zero);
      expect(analise.freeDuration, const Duration(hours: 15));
      expect(analise.focusBlocks.length, 1);
    });

    test('REGRESSÃO: evento antes das 07h não "come" nenhum tempo livre', () {
      final eventos = [_buildEvent(id: 'a', start: DateTime(2026, 1, 1, 3), end: DateTime(2026, 1, 1, 5))];

      final analise = service.analyze(eventos, now: referencia);

      expect(analise.busyDuration, Duration.zero);
      expect(analise.freeDuration, const Duration(hours: 15));
      expect(analise.focusBlocks.length, 1);
    });
  });

  group('Eventos de dia inteiro e excluídos', () {
    test('não entram no cálculo de tempo ocupado/livre, mas contam em eventCount', () {
      final eventos = [
        _buildEvent(id: 'a', start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 1, 23, 59), allDay: true),
        _buildEvent(id: 'b', start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 10)),
      ];

      final analise = service.analyze(eventos, now: referencia);

      expect(analise.eventCount, 1); // só o evento com horário conta para a análise de tempo
      expect(analise.busyDuration, const Duration(hours: 1));
    });
  });
}

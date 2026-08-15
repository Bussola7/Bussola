import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/services/day_summary_service.dart';
import 'package:bussola/features/agenda/domain/services/schedule_analyzer_service.dart';

EventModel _buildEvent({required String id, required Priority priority}) {
  final now = DateTime.now();
  return EventModel(
    id: id,
    calendarId: 'cal-1',
    userId: 'user-1',
    title: 'Evento $id',
    startDatetime: DateTime(2026, 1, 1, 9),
    endDatetime: DateTime(2026, 1, 1, 10),
    timezone: 'America/Sao_Paulo',
    allDay: false,
    priority: priority,
    createdAt: now,
    updatedAt: now,
  );
}

DayScheduleAnalysis _buildAnalysis({
  required int eventCount,
  required Duration freeDuration,
  Duration? largestFreeInterval,
}) {
  return DayScheduleAnalysis(
    eventCount: eventCount,
    busyDuration: const Duration(hours: 15) - freeDuration,
    freeDuration: freeDuration,
    largestFreeInterval: largestFreeInterval ?? freeDuration,
    smallestFreeInterval: freeDuration,
    focusBlocks: const [],
    completedCount: 0,
    pendingCount: eventCount,
  );
}

void main() {
  final service = DaySummaryService();

  group('Resumo de dia vazio', () {
    test('mensagem de fechamento específica quando não há nenhum evento', () {
      final analise = _buildAnalysis(eventCount: 0, freeDuration: const Duration(hours: 15));

      final resumo = service.generate(eventsOfDay: const [], analysis: analise);

      expect(resumo.eventCount, 0);
      expect(resumo.closingRemark, 'Seu dia está livre.');
      expect(resumo.greetingText, contains('Bom dia!'));
    });
  });

  group('Resumo de dia leve', () {
    test('fechamento "tranquilo" quando sobra bastante tempo livre', () {
      final eventos = [_buildEvent(id: 'a', priority: Priority.baixa)];
      final analise = _buildAnalysis(eventCount: 1, freeDuration: const Duration(hours: 14));

      final resumo = service.generate(eventsOfDay: eventos, analysis: analise);

      expect(resumo.closingRemark, contains('tranquilo'));
    });
  });

  group('Resumo de dia intenso', () {
    test('fechamento "intenso" quando sobra pouco tempo livre', () {
      final eventos = [_buildEvent(id: 'a', priority: Priority.alta)];
      final analise = _buildAnalysis(eventCount: 1, freeDuration: const Duration(hours: 1)); // < 1h30

      final resumo = service.generate(eventsOfDay: eventos, analysis: analise);

      expect(resumo.closingRemark, 'Seu dia será intenso.');
    });
  });

  group('Resumo de dia equilibrado', () {
    test('fechamento "equilibrado" numa faixa intermediária de tempo livre', () {
      final analise = _buildAnalysis(eventCount: 2, freeDuration: const Duration(hours: 2, minutes: 30));

      final resumo = service.generate(eventsOfDay: const [], analysis: analise);

      expect(resumo.closingRemark, contains('equilibrado'));
    });
  });

  group('Cálculo de reuniões importantes', () {
    test('conta só eventos de prioridade Alta ou Muito Alta', () {
      final eventos = [
        _buildEvent(id: 'a', priority: Priority.alta),
        _buildEvent(id: 'b', priority: Priority.muitoAlta),
        _buildEvent(id: 'c', priority: Priority.media),
        _buildEvent(id: 'd', priority: Priority.baixa),
      ];
      final analise = _buildAnalysis(eventCount: 4, freeDuration: const Duration(hours: 5));

      final resumo = service.generate(eventsOfDay: eventos, analysis: analise);

      expect(resumo.importantMeetingsCount, 2);
    });
  });

  group('Geração do texto do Norte do Dia', () {
    test('o texto final inclui compromissos, reuniões importantes e maior intervalo', () {
      final eventos = [_buildEvent(id: 'a', priority: Priority.alta)];
      final analise = _buildAnalysis(
        eventCount: 3,
        freeDuration: const Duration(hours: 3),
        largestFreeInterval: const Duration(hours: 1, minutes: 40),
      );

      final resumo = service.generate(eventsOfDay: eventos, analysis: analise);
      final texto = resumo.greetingText;

      expect(texto, contains('3 compromissos'));
      expect(texto, contains('1 reunião importante'));
      expect(texto, contains('3h'));
      expect(texto, contains('1h40'));
    });
  });
}

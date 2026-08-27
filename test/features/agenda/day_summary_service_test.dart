import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/services/day_summary_service.dart';
import 'package:bussola/features/agenda/domain/services/schedule_analyzer_service.dart';

EventModel _buildEvent({
  required String id,
  required Priority priority,
  DateTime? startDatetime,
  DateTime? endDatetime,
  bool allDay = false,
  String title = 'Reunião',
}) {
  final now = DateTime.now();
  return EventModel(
    id: id,
    calendarId: 'cal-1',
    userId: 'user-1',
    title: title,
    startDatetime: startDatetime ?? DateTime(2026, 1, 1, 9),
    endDatetime: endDatetime ?? (startDatetime ?? DateTime(2026, 1, 1, 9)).add(const Duration(hours: 1)),
    timezone: 'America/Sao_Paulo',
    allDay: allDay,
    priority: priority,
    createdAt: now,
    updatedAt: now,
  );
}

DayScheduleAnalysis _buildAnalysis({
  required int eventCount,
  required Duration freeDuration,
  Duration? largestFreeInterval,
  List<FocusBlock> focusBlocks = const [],
}) {
  return DayScheduleAnalysis(
    eventCount: eventCount,
    busyDuration: const Duration(hours: 15) - freeDuration,
    freeDuration: freeDuration,
    largestFreeInterval: largestFreeInterval ?? freeDuration,
    smallestFreeInterval: freeDuration,
    focusBlocks: focusBlocks,
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
    test('fechamento "intenso" quando sobra pouco tempo livre e não há reunião importante', () {
      final eventos = [_buildEvent(id: 'a', priority: Priority.media)];
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

  group('Fechamento dinâmico com reunião importante', () {
    test('menciona a reunião importante quando ela é cedo (antes das 10h)', () {
      final eventos = [_buildEvent(id: 'a', priority: Priority.alta, startDatetime: DateTime(2026, 1, 1, 8, 30))];
      final analise = _buildAnalysis(eventCount: 1, freeDuration: const Duration(hours: 10));

      final resumo = service.generate(eventsOfDay: eventos, analysis: analise);

      expect(resumo.closingRemark, contains('08:30'));
    });

    test('menciona a reunião importante mesmo não sendo cedo', () {
      final eventos = [_buildEvent(id: 'a', priority: Priority.alta, startDatetime: DateTime(2026, 1, 1, 15))];
      final analise = _buildAnalysis(eventCount: 1, freeDuration: const Duration(hours: 10));

      final resumo = service.generate(eventsOfDay: eventos, analysis: analise);

      expect(resumo.closingRemark, contains('15:00'));
    });
  });

  group('DaySummary.nextAction', () {
    final agora = DateTime(2026, 1, 1, 8);

    test('sugere se preparar quando há reunião importante que ainda vai acontecer', () {
      final eventos = [
        _buildEvent(id: 'a', priority: Priority.muitoAlta, startDatetime: DateTime(2026, 1, 1, 10), title: 'Board'),
      ];
      final analise = _buildAnalysis(eventCount: 1, freeDuration: const Duration(hours: 10));

      final resumo = service.generate(eventsOfDay: eventos, analysis: analise, now: agora);

      expect(resumo.nextAction.destino, NextActionDestino.agenda);
      expect(resumo.nextAction.texto, contains('10:00'));
    });

    test('ignora reunião importante que já passou', () {
      final eventos = [_buildEvent(id: 'a', priority: Priority.alta, startDatetime: DateTime(2026, 1, 1, 6))];
      final analise = _buildAnalysis(
        eventCount: 1,
        freeDuration: const Duration(hours: 10),
        focusBlocks: [FocusBlock(start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 12))],
      );

      final resumo = service.generate(eventsOfDay: eventos, analysis: analise, now: agora);

      expect(resumo.nextAction.destino, NextActionDestino.tarefas);
    });

    test('sugere focar numa tarefa quando o maior bloco livre é grande (>= 2h) e não há reunião futura', () {
      final analise = _buildAnalysis(
        eventCount: 0,
        freeDuration: const Duration(hours: 10),
        focusBlocks: [FocusBlock(start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 12))],
      );

      final resumo = service.generate(eventsOfDay: const [], analysis: analise, now: agora);

      expect(resumo.nextAction.destino, NextActionDestino.tarefas);
      expect(resumo.nextAction.texto, contains('09:00'));
    });

    test('não sugere foco quando o maior bloco livre é pequeno (< 2h)', () {
      final analise = _buildAnalysis(
        eventCount: 1,
        freeDuration: const Duration(hours: 1),
        focusBlocks: [FocusBlock(start: DateTime(2026, 1, 1, 9), end: DateTime(2026, 1, 1, 9, 45))],
      );

      final resumo = service.generate(eventsOfDay: const [], analysis: analise, now: agora);

      expect(resumo.nextAction.destino, NextActionDestino.agenda);
      expect(resumo.nextAction.texto, isNot(contains('09:00')));
    });

    test('sugere planejar tarefas quando o dia está totalmente livre', () {
      final analise = _buildAnalysis(eventCount: 0, freeDuration: const Duration(hours: 15));

      final resumo = service.generate(eventsOfDay: const [], analysis: analise, now: agora);

      expect(resumo.nextAction.destino, NextActionDestino.tarefas);
      expect(resumo.nextAction.texto, contains('livre'));
    });
  });
}

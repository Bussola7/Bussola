import 'package:bussola/features/agenda/data/models/event_model.dart';

/// Um intervalo contínuo sem nenhum evento — vira "bloco de foco" quando
/// for longo o suficiente ([ScheduleAnalyzerService.focoMinimoMinutos]).
class FocusBlock {
  final DateTime start;
  final DateTime end;

  const FocusBlock({required this.start, required this.end});

  Duration get duration => end.difference(start);
}

/// Resultado completo da análise de um dia. Um único objeto, calculado
/// uma única vez — o Dashboard ("Norte do Dia" e "Estatísticas") lê os
/// campos daqui em vez de cada cartão recalcular tempo livre por conta
/// própria (evita consulta/cálculo repetido, como pedido na etapa).
class DayScheduleAnalysis {
  final int eventCount;
  final Duration busyDuration;
  final Duration freeDuration;
  final Duration? largestFreeInterval;
  final Duration? smallestFreeInterval;
  final List<FocusBlock> focusBlocks;
  final int completedCount;
  final int pendingCount;

  const DayScheduleAnalysis({
    required this.eventCount,
    required this.busyDuration,
    required this.freeDuration,
    required this.largestFreeInterval,
    required this.smallestFreeInterval,
    required this.focusBlocks,
    required this.completedCount,
    required this.pendingCount,
  });
}

/// Analisa a agenda de um dia usando só regras — nenhuma IA. Considera
/// uma "janela do dia" (07h–22h) como referência de tempo livre/ocupado:
/// contar o dia inteiro (24h) tornaria "3 horas livres" um número sem
/// sentido prático, já que sempre sobra madrugada livre.
class ScheduleAnalyzerService {
  static const int horaInicioDaJanela = 7;
  static const int horaFimDaJanela = 22;
  static const int focoMinimoMinutos = 30;

  DayScheduleAnalysis analyze(List<EventModel> eventsOfDay, {DateTime? now}) {
    final ativos = eventsOfDay.where((e) => !e.isDeleted && !e.allDay).toList()
      ..sort((a, b) => a.startDatetime.compareTo(b.startDatetime));

    final referencia = now ?? DateTime.now();

    if (ativos.isEmpty) {
      final inicioJanelaVazia = DateTime(referencia.year, referencia.month, referencia.day, horaInicioDaJanela);
      final fimJanelaVazia = DateTime(referencia.year, referencia.month, referencia.day, horaFimDaJanela);
      final janelaCompleta = fimJanelaVazia.difference(inicioJanelaVazia);
      return DayScheduleAnalysis(
        eventCount: eventsOfDay.where((e) => !e.isDeleted).length,
        busyDuration: Duration.zero,
        freeDuration: janelaCompleta,
        largestFreeInterval: janelaCompleta,
        smallestFreeInterval: janelaCompleta,
        focusBlocks: [FocusBlock(start: inicioJanelaVazia, end: fimJanelaVazia)],
        completedCount: 0,
        pendingCount: 0,
      );
    }

    final diaBase = ativos.first.startDatetime;
    final inicioJanela = DateTime(diaBase.year, diaBase.month, diaBase.day, horaInicioDaJanela);
    final fimJanela = DateTime(diaBase.year, diaBase.month, diaBase.day, horaFimDaJanela);

    Duration ocupado = Duration.zero;
    final gaps = <Duration>[];
    final blocos = <FocusBlock>[];

    DateTime cursor = inicioJanela;
    DateTime clampToWindow(DateTime d) {
      if (d.isBefore(inicioJanela)) return inicioJanela;
      if (d.isAfter(fimJanela)) return fimJanela;
      return d;
    }

    for (final evento in ativos) {
      final inicioEvento = clampToWindow(evento.startDatetime);
      final fimEvento = clampToWindow(evento.endDatetime);
      if (!fimEvento.isAfter(cursor)) continue; // evento todo antes da janela/cursor

      if (inicioEvento.isAfter(cursor)) {
        final gap = inicioEvento.difference(cursor);
        gaps.add(gap);
        if (gap.inMinutes >= focoMinimoMinutos) {
          blocos.add(FocusBlock(start: cursor, end: inicioEvento));
        }
      }

      final inicioOcupado = inicioEvento.isBefore(cursor) ? cursor : inicioEvento;
      if (fimEvento.isAfter(inicioOcupado)) {
        ocupado += fimEvento.difference(inicioOcupado);
      }
      if (fimEvento.isAfter(cursor)) cursor = fimEvento;
    }

    if (fimJanela.isAfter(cursor)) {
      final gap = fimJanela.difference(cursor);
      gaps.add(gap);
      if (gap.inMinutes >= focoMinimoMinutos) {
        blocos.add(FocusBlock(start: cursor, end: fimJanela));
      }
    }

    final duracaoJanela = fimJanela.difference(inicioJanela);
    final livre = duracaoJanela - ocupado;

    gaps.sort((a, b) => a.compareTo(b));

    return DayScheduleAnalysis(
      eventCount: ativos.length,
      busyDuration: ocupado,
      freeDuration: livre.isNegative ? Duration.zero : livre,
      largestFreeInterval: gaps.isEmpty ? null : gaps.last,
      smallestFreeInterval: gaps.isEmpty ? null : gaps.first,
      focusBlocks: blocos,
      completedCount: ativos.where((e) => e.endDatetime.isBefore(referencia)).length,
      pendingCount: ativos.where((e) => e.startDatetime.isAfter(referencia)).length,
    );
  }
}

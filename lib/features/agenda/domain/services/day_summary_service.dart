import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/services/schedule_analyzer_service.dart';

/// Resultado do "Norte do Dia": dados estruturados (para o cartão do
/// Dashboard desenhar do jeito que quiser, com o Design System) + uma
/// saudação textual pronta, para quando só o texto for suficiente.
class DaySummary {
  final int eventCount;
  final int importantMeetingsCount;
  final Duration freeDuration;
  final Duration? largestFreeInterval;
  final String closingRemark;

  const DaySummary({
    required this.eventCount,
    required this.importantMeetingsCount,
    required this.freeDuration,
    required this.largestFreeInterval,
    required this.closingRemark,
  });

  String get greetingText {
    final buffer = StringBuffer('Bom dia!\n\nHoje você possui:\n');
    buffer.writeln('• $eventCount compromisso${eventCount == 1 ? '' : 's'}');
    if (importantMeetingsCount > 0) {
      buffer.writeln('• $importantMeetingsCount reunião${importantMeetingsCount == 1 ? '' : 'ões'} importante${importantMeetingsCount == 1 ? '' : 's'}');
    }
    buffer.writeln('• ${_formatDuration(freeDuration)} livres');
    if (largestFreeInterval != null) {
      buffer.writeln('• Seu maior intervalo livre é de ${_formatDuration(largestFreeInterval!)}');
    }
    buffer.write('\n$closingRemark');
    return buffer.toString();
  }

  static String _formatDuration(Duration d) {
    final horas = d.inHours;
    final minutos = d.inMinutes % 60;
    if (horas == 0) return '$minutos min';
    if (minutos == 0) return '${horas}h';
    return '${horas}h${minutos.toString().padLeft(2, '0')}';
  }
}

/// Gera o "Norte do Dia" — só regras (nenhuma chamada de IA). "Reunião
/// importante" nesta versão é qualquer evento de prioridade Alta ou Muito
/// Alta — uma regra simples, fácil de a IA (Sprint futura) substituir por
/// algo mais sofisticado sem mudar quem consome este serviço.
class DaySummaryService {
  DaySummary generate({
    required List<EventModel> eventsOfDay,
    required DayScheduleAnalysis analysis,
  }) {
    final importantes = eventsOfDay
        .where((e) => !e.isDeleted && (e.priority == Priority.alta || e.priority == Priority.muitoAlta))
        .length;

    return DaySummary(
      eventCount: analysis.eventCount,
      importantMeetingsCount: importantes,
      freeDuration: analysis.freeDuration,
      largestFreeInterval: analysis.largestFreeInterval,
      closingRemark: _closingRemark(analysis),
    );
  }

  /// Regra simples baseada só no tempo livre calculado — sem IA.
  String _closingRemark(DayScheduleAnalysis analysis) {
    final horasLivres = analysis.freeDuration.inMinutes / 60;
    if (analysis.eventCount == 0) return 'Seu dia está livre.';
    if (horasLivres < 1.5) return 'Seu dia será intenso.';
    if (horasLivres < 3.5) return 'Um dia equilibrado pela frente.';
    return 'Um dia tranquilo — aproveite o tempo livre.';
  }
}

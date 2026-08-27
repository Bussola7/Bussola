import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/services/schedule_analyzer_service.dart';

/// Para onde o botão da sugestão de próxima ação leva.
enum NextActionDestino { agenda, tarefas }

/// Sugestão de próxima ação do dia — regras simples (sem IA) baseadas na
/// [DayScheduleAnalysis] e nos eventos já calculados: prioriza avisar de
/// uma reunião importante que ainda vai acontecer; na falta dela, sugere
/// aproveitar o maior bloco de tempo livre para uma tarefa.
class NextAction {
  final String texto;
  final String rotuloBotao;
  final NextActionDestino destino;

  const NextAction({required this.texto, required this.rotuloBotao, required this.destino});
}

/// Resultado do "Norte do Dia": dados estruturados (para o cartão do
/// Dashboard desenhar do jeito que quiser, com o Design System) + uma
/// saudação textual pronta, para quando só o texto for suficiente.
class DaySummary {
  final int eventCount;
  final int importantMeetingsCount;
  final Duration freeDuration;
  final Duration? largestFreeInterval;
  final String closingRemark;
  final NextAction nextAction;

  const DaySummary({
    required this.eventCount,
    required this.importantMeetingsCount,
    required this.freeDuration,
    required this.largestFreeInterval,
    required this.closingRemark,
    required this.nextAction,
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
    DateTime? now,
  }) {
    final agora = now ?? DateTime.now();

    final importantesTodas = eventsOfDay
        .where((e) => !e.isDeleted && (e.priority == Priority.alta || e.priority == Priority.muitoAlta))
        .toList()
      ..sort((a, b) => a.startDatetime.compareTo(b.startDatetime));

    return DaySummary(
      eventCount: analysis.eventCount,
      importantMeetingsCount: importantesTodas.length,
      freeDuration: analysis.freeDuration,
      largestFreeInterval: analysis.largestFreeInterval,
      closingRemark: _closingRemark(analysis, importantesTodas),
      nextAction: _proximaAcao(analysis, importantesTodas, agora),
    );
  }

  /// Regra baseada em tempo livre e reuniões importantes — sem IA. Avisa
  /// cedo quando há uma reunião importante logo de manhã, alerta quando o
  /// dia está cheio, e só fica "tranquilo" quando os dois sinais permitem.
  String _closingRemark(DayScheduleAnalysis analysis, List<EventModel> importantes) {
    if (analysis.eventCount == 0) return 'Seu dia está livre.';

    final horasLivres = analysis.freeDuration.inMinutes / 60;

    if (importantes.isNotEmpty) {
      final primeira = importantes.first.startDatetime.toLocal();
      if (primeira.hour < 10) {
        return 'Comece focado: sua reunião importante é às ${_formatarHora(primeira)}.';
      }
      if (horasLivres < 1.5) {
        return 'Dia intenso, com reunião importante às ${_formatarHora(primeira)} — organize-se.';
      }
      return 'Você tem uma reunião importante às ${_formatarHora(primeira)} hoje.';
    }

    if (horasLivres < 1.5) return 'Seu dia será intenso.';
    if (horasLivres < 3.5) return 'Um dia equilibrado pela frente.';
    return 'Um dia tranquilo — aproveite o tempo livre.';
  }

  /// Prioriza avisar da próxima reunião importante que ainda vai
  /// acontecer; sem uma, sugere o maior bloco livre (só se for grande o
  /// bastante pra valer a pena, >= 2h); sem nenhum dos dois, cai num
  /// texto neutro conforme o dia estar vazio ou só sem nada de especial.
  NextAction _proximaAcao(DayScheduleAnalysis analysis, List<EventModel> importantes, DateTime agora) {
    final importantesFuturas = importantes.where((e) => !e.allDay && e.startDatetime.isAfter(agora)).toList();

    if (importantesFuturas.isNotEmpty) {
      final proxima = importantesFuturas.first.startDatetime.toLocal();
      return NextAction(
        texto: 'Prepare-se: sua reunião importante começa às ${_formatarHora(proxima)}.',
        rotuloBotao: 'Ver agenda',
        destino: NextActionDestino.agenda,
      );
    }

    if (analysis.focusBlocks.isNotEmpty) {
      final maiorBloco = analysis.focusBlocks.reduce((a, b) => a.duration > b.duration ? a : b);
      if (maiorBloco.duration.inMinutes >= 120) {
        final inicio = maiorBloco.start.toLocal();
        return NextAction(
          texto: 'Você tem ${DaySummary._formatDuration(maiorBloco.duration)} livres a partir de '
              '${_formatarHora(inicio)} — bom momento para focar em uma tarefa.',
          rotuloBotao: 'Ver tarefas',
          destino: NextActionDestino.tarefas,
        );
      }
    }

    if (analysis.eventCount == 0) {
      return const NextAction(
        texto: 'Seu dia está livre — bom momento para planejar suas tarefas.',
        rotuloBotao: 'Ver tarefas',
        destino: NextActionDestino.tarefas,
      );
    }

    return const NextAction(
      texto: 'Nenhuma reunião importante nem grandes blocos livres agora — siga com o que já está planejado.',
      rotuloBotao: 'Ver agenda',
      destino: NextActionDestino.agenda,
    );
  }

  String _formatarHora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

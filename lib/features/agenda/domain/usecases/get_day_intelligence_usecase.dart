import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/services/day_summary_service.dart';
import 'package:bussola/features/agenda/domain/services/schedule_analyzer_service.dart';
import 'package:bussola/features/agenda/domain/usecases/get_day_schedule_analysis_usecase.dart';

/// Empacota tudo que o Dashboard precisa do dia atual: a análise
/// (estatísticas), o resumo, e os próprios eventos (ex: para achar o
/// próximo compromisso). Um único Use Case, uma única busca de eventos —
/// quem consome isto lê os campos daqui, em vez de buscar/calcular de novo.
class DayIntelligence {
  final DayScheduleAnalysis analysis;
  final DaySummary summary;
  final List<EventModel> events;

  const DayIntelligence({required this.analysis, required this.summary, required this.events});
}

class GetDayIntelligenceUseCase {
  final GetDayScheduleAnalysisUseCase _getAnalysis;
  final DaySummaryService _summaryService;

  GetDayIntelligenceUseCase({GetDayScheduleAnalysisUseCase? getAnalysis, DaySummaryService? summaryService})
      : _getAnalysis = getAnalysis ?? GetDayScheduleAnalysisUseCase(),
        _summaryService = summaryService ?? DaySummaryService();

  Future<DayIntelligence> execute({required String userId, required DateTime day}) async {
    final resultado = await _getAnalysis.execute(userId: userId, day: day);
    final resumo = _summaryService.generate(eventsOfDay: resultado.events, analysis: resultado.analysis);
    return DayIntelligence(analysis: resultado.analysis, summary: resumo, events: resultado.events);
  }
}

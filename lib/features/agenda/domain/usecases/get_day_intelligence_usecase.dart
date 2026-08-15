import 'package:bussola/features/agenda/domain/services/day_summary_service.dart';
import 'package:bussola/features/agenda/domain/services/schedule_analyzer_service.dart';
import 'package:bussola/features/agenda/domain/usecases/get_day_schedule_analysis_usecase.dart';

/// Empacota tudo que o Dashboard precisa do dia atual: a análise
/// (estatísticas) e o resumo (Norte do Dia). Um único Use Case, uma
/// única busca de eventos — os cartões "Norte do Dia" e "Estatísticas"
/// leem os campos daqui, em vez de cada um buscar/calcular por conta própria.
class DayIntelligence {
  final DayScheduleAnalysis analysis;
  final DaySummary summary;

  const DayIntelligence({required this.analysis, required this.summary});
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
    return DayIntelligence(analysis: resultado.analysis, summary: resumo);
  }
}

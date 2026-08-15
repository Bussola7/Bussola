import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/services/schedule_analyzer_service.dart';
import 'package:bussola/features/agenda/domain/usecases/get_events_usecase.dart';

/// Busca os eventos do dia e devolve a análise completa (tempo livre,
/// blocos de foco, contagens). Um único ponto de entrada — quem quiser
/// "Norte do Dia" ou "Estatísticas" usa este mesmo resultado, em vez de
/// cada tela buscar os eventos e calcular de novo por conta própria.
class GetDayScheduleAnalysisUseCase {
  final GetEventsUseCase _getEvents;
  final ScheduleAnalyzerService _analyzer;

  GetDayScheduleAnalysisUseCase({GetEventsUseCase? getEvents, ScheduleAnalyzerService? analyzer})
      : _getEvents = getEvents ?? GetEventsUseCase(),
        _analyzer = analyzer ?? ScheduleAnalyzerService();

  Future<({DayScheduleAnalysis analysis, List<EventModel> events})> execute({
    required String userId,
    required DateTime day,
  }) async {
    final inicio = DateTime(day.year, day.month, day.day);
    final fim = inicio.add(const Duration(days: 1));
    final eventos = await _getEvents.execute(userId: userId, start: inicio, end: fim);
    final analise = _analyzer.analyze(eventos, now: DateTime.now());
    return (analysis: analise, events: eventos);
  }
}

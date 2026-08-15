import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/features/agenda/domain/usecases/get_day_intelligence_usecase.dart';

/// Norte do Dia + Estatísticas de hoje, para o usuário [userId].
/// `family` porque depende de quem está logado; o Riverpod já cuida do
/// cache (não busca de novo enquanto o provider continuar "vivo" na tela).
final dayIntelligenceProvider = FutureProvider.family<DayIntelligence, String>((ref, userId) {
  return GetDayIntelligenceUseCase().execute(userId: userId, day: DateTime.now());
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/features/agenda/domain/usecases/get_day_intelligence_usecase.dart';
import 'package:bussola/shared/models/life_area.dart';

/// Norte do Dia + Estatísticas de hoje, para o usuário [userId].
/// `family` porque depende de quem está logado; o Riverpod já cuida do
/// cache (não busca de novo enquanto o provider continuar "vivo" na tela).
final dayIntelligenceProvider = FutureProvider.family<DayIntelligence, String>((ref, userId) {
  return GetDayIntelligenceUseCase().execute(userId: userId, day: DateTime.now());
});

/// Área do próximo compromisso do dia (o mesmo que o [FocusChip] e o
/// [NextAppointmentCard] mostram) — `null` enquanto carrega, em erro, ou
/// se não há compromisso futuro com área definida. Fica num provider
/// derivado só pra não duplicar essa conta em cada widget que precisa
/// dela (chip da Hoje e a seção "Tarefas de hoje" filtram por ela).
final focusAreaProvider = Provider.family<LifeArea?, String>((ref, userId) {
  final async = ref.watch(dayIntelligenceProvider(userId));
  return async.maybeWhen(
    data: (data) {
      final agora = DateTime.now();
      final futuroComArea = data.events
          .where((e) => !e.isDeleted && !e.allDay && e.startDatetime.isAfter(agora) && e.lifeArea != null)
          .toList()
        ..sort((a, b) => a.startDatetime.compareTo(b.startDatetime));
      return futuroComArea.isEmpty ? null : futuroComArea.first.lifeArea;
    },
    orElse: () => null,
  );
});

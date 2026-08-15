import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/presentation/providers/calendar_ui_provider.dart';
import 'package:bussola/features/agenda/presentation/state/calendar_ui_state.dart';

void main() {
  group('CalendarUiNotifier', () {
    test('modo Dia: próximo avança 1 dia e anterior volta 1 dia', () {
      final notifier = CalendarUiNotifier();
      notifier.setViewMode(CalendarViewMode.dia);
      final dataInicial = notifier.state.focusedDate;

      notifier.goToNext();
      expect(notifier.state.focusedDate.difference(dataInicial).inDays, 1);

      notifier.goToPrevious();
      notifier.goToPrevious();
      expect(notifier.state.focusedDate.difference(dataInicial).inDays, -1);
    });

    test('modo Semana: próximo avança 7 dias', () {
      final notifier = CalendarUiNotifier();
      notifier.setViewMode(CalendarViewMode.semana);
      final dataInicial = notifier.state.focusedDate;

      notifier.goToNext();

      expect(notifier.state.focusedDate.difference(dataInicial).inDays, 7);
    });

    test('modo Mês: próximo avança para o mês seguinte (dia 1)', () {
      final notifier = CalendarUiNotifier();
      notifier.setViewMode(CalendarViewMode.mes);

      notifier.goToNext();

      final novaData = notifier.state.focusedDate;
      final agora = DateTime.now();
      final mesEsperado = DateTime(agora.year, agora.month + 1, 1);
      expect(novaData.year, mesEsperado.year);
      expect(novaData.month, mesEsperado.month);
      expect(novaData.day, 1);
    });

    test('goToToday volta para a data atual independentemente do modo', () {
      final notifier = CalendarUiNotifier();
      notifier.setViewMode(CalendarViewMode.mes);
      notifier.goToNext();
      notifier.goToNext();

      notifier.goToToday();

      final hoje = DateTime.now();
      expect(notifier.state.focusedDate.year, hoje.year);
      expect(notifier.state.focusedDate.month, hoje.month);
      expect(notifier.state.focusedDate.day, hoje.day);
    });

    test('visibleRange no modo Semana cobre 7 dias a partir do domingo', () {
      final notifier = CalendarUiNotifier();
      notifier.setViewMode(CalendarViewMode.semana);

      final range = notifier.visibleRange;

      expect(range.end.difference(range.start).inDays, 7);
      expect(range.start.weekday % 7, 0); // domingo
    });
  });
}

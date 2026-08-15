import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/utils/date_formatting.dart';
import 'package:bussola/features/agenda/presentation/state/calendar_ui_state.dart';

/// Controla a navegação da tela de calendário: trocar de modo (Dia/Semana/
/// Mês/Lista) e mover a data em foco (anterior/próxima/hoje). O tamanho do
/// "passo" ao navegar depende do modo atual — 1 dia no modo Dia, 7 dias no
/// modo Semana, 1 mês no modo Mês. No modo Lista, navega por mês também
/// (é a visão de lista do mesmo período do Mês).
class CalendarUiNotifier extends StateNotifier<CalendarUiState> {
  CalendarUiNotifier() : super(CalendarUiState.initial());

  void setViewMode(CalendarViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void goToToday() {
    state = state.copyWith(focusedDate: DateTime.now());
  }

  void goToNext() => _move(1);

  void goToPrevious() => _move(-1);

  void _move(int direction) {
    switch (state.viewMode) {
      case CalendarViewMode.dia:
        state = state.copyWith(focusedDate: state.focusedDate.add(Duration(days: direction)));
        break;
      case CalendarViewMode.semana:
        state = state.copyWith(focusedDate: state.focusedDate.add(Duration(days: 7 * direction)));
        break;
      case CalendarViewMode.mes:
      case CalendarViewMode.lista:
        final novoMes = DateTime(state.focusedDate.year, state.focusedDate.month + direction, 1);
        state = state.copyWith(focusedDate: novoMes);
        break;
    }
  }

  /// Intervalo de datas visível no modo atual — útil quando a Etapa 2.2
  /// plugar o `EventNotifier` (que já espera um `start`/`end`).
  ({DateTime start, DateTime end}) get visibleRange {
    switch (state.viewMode) {
      case CalendarViewMode.dia:
        final dia = DateFormatting.apenasData(state.focusedDate);
        return (start: dia, end: dia.add(const Duration(days: 1)));
      case CalendarViewMode.semana:
        final inicio = DateFormatting.inicioDaSemana(state.focusedDate);
        return (start: inicio, end: inicio.add(const Duration(days: 7)));
      case CalendarViewMode.mes:
      case CalendarViewMode.lista:
        final inicio = DateTime(state.focusedDate.year, state.focusedDate.month, 1);
        final fim = DateTime(state.focusedDate.year, state.focusedDate.month + 1, 1);
        return (start: inicio, end: fim);
    }
  }
}

final calendarUiNotifierProvider = StateNotifierProvider<CalendarUiNotifier, CalendarUiState>(
  (ref) => CalendarUiNotifier(),
);

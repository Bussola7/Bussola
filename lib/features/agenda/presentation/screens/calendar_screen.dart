import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/utils/date_formatting.dart';
import 'package:bussola/features/agenda/data/models/calendar_model.dart';
import 'package:bussola/features/agenda/presentation/providers/calendar_provider.dart';
import 'package:bussola/features/agenda/presentation/providers/calendar_ui_provider.dart';
import 'package:bussola/features/agenda/presentation/providers/event_provider.dart';
import 'package:bussola/features/agenda/presentation/state/calendar_ui_state.dart';
import 'package:bussola/features/agenda/presentation/screens/event_editor_screen.dart';
import 'package:bussola/features/agenda/presentation/widgets/agenda_list_view.dart';
import 'package:bussola/features/agenda/presentation/widgets/bussola_fab.dart';
import 'package:bussola/features/agenda/presentation/widgets/calendar_header.dart';
import 'package:bussola/features/agenda/presentation/widgets/day_view.dart';
import 'package:bussola/features/agenda/presentation/widgets/month_view.dart';
import 'package:bussola/features/agenda/presentation/widgets/week_view.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';

/// Tela da aba "Agenda": header + a visualização ativa + FAB para criar
/// um novo compromisso. Também é quem decide QUANDO recarregar os
/// eventos (a cada troca de período), para nenhuma das 4 visualizações
/// precisar se preocupar com isso.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime? _lastRangeStart;
  DateTime? _lastRangeEnd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authNotifierProvider).user?.id;
      if (userId == null) return;
      ref.read(calendarNotifierProvider.notifier).load(userId);
      _reloadEventsForCurrentRange(userId);
    });
  }

  void _reloadEventsForCurrentRange(String userId) {
    final range = ref.read(calendarUiNotifierProvider.notifier).visibleRange;
    if (_lastRangeStart == range.start && _lastRangeEnd == range.end) return;
    _lastRangeStart = range.start;
    _lastRangeEnd = range.end;
    ref.read(eventNotifierProvider.notifier).loadPeriod(userId: userId, start: range.start, end: range.end);
  }

  String _defaultCalendarId(List<CalendarModel> calendars) {
    if (calendars.isEmpty) return '';
    final padrao = calendars.where((c) => c.isDefault);
    return padrao.isNotEmpty ? padrao.first.id : calendars.first.id;
  }

  String _titleFor(CalendarUiState uiState) {
    final data = uiState.focusedDate;
    switch (uiState.viewMode) {
      case CalendarViewMode.dia:
        return DateFormatting.diaSemanaEData(data);
      case CalendarViewMode.semana:
        final inicio = DateFormatting.inicioDaSemana(data);
        final fim = inicio.add(const Duration(days: 6));
        return DateFormatting.intervaloSemana(inicio, fim);
      case CalendarViewMode.mes:
      case CalendarViewMode.lista:
        return DateFormatting.mesAno(data);
    }
  }

  Widget _viewFor(CalendarUiState uiState, String userId) {
    switch (uiState.viewMode) {
      case CalendarViewMode.dia:
        return DayView(focusedDate: uiState.focusedDate);
      case CalendarViewMode.semana:
        return WeekView(focusedDate: uiState.focusedDate);
      case CalendarViewMode.mes:
        return MonthView(focusedDate: uiState.focusedDate);
      case CalendarViewMode.lista:
        return AgendaListView(focusedDate: uiState.focusedDate, userId: userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(calendarUiNotifierProvider);
    final notifier = ref.read(calendarUiNotifierProvider.notifier);
    final userId = ref.watch(authNotifierProvider).user?.id;
    final calendars = ref.watch(calendarNotifierProvider).calendars;

    // Recarrega os eventos sempre que o período visível mudar (troca de
    // modo ou navegação de data) — sem precisar que cada visualização
    // saiba disso.
    ref.listen<CalendarUiState>(calendarUiNotifierProvider, (previous, next) {
      if (userId != null) _reloadEventsForCurrentRange(userId);
    });

    return Stack(
      children: [
        Column(
          children: [
            CalendarHeader(
              title: _titleFor(uiState),
              viewMode: uiState.viewMode,
              onPrevious: notifier.goToPrevious,
              onNext: notifier.goToNext,
              onToday: notifier.goToToday,
              onViewModeChanged: notifier.setViewMode,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(
                        '${uiState.viewMode}-${uiState.focusedDate.year}-${uiState.focusedDate.month}-${uiState.focusedDate.day}'),
                    child: userId == null
                        ? const SizedBox.shrink()
                        : _viewFor(uiState, userId),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (userId != null)
          Positioned(
            right: 20,
            bottom: 20,
            child: BussolaFab(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EventEditorScreen(
                    calendarId: _defaultCalendarId(calendars),
                    userId: userId,
                    initialDate: uiState.focusedDate,
                  ),
                ));
              },
            ),
          ),
      ],
    );
  }
}

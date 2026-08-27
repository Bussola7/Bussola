import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
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
import 'package:bussola/features/agenda/presentation/widgets/unified_agenda_list_view.dart';
import 'package:bussola/features/agenda/presentation/widgets/week_view.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';

/// Tela da aba "Agenda": um alternador no topo escolhe entre a visão
/// "Lista" (tarefas + eventos juntos, ordenados por horário — via
/// [UnifiedAgendaListView]) e a visão "Calendário" (dia/semana/mês/lista de
/// eventos, exatamente como já funcionava). FAB cria um novo compromisso
/// nas duas visões. Também é quem decide QUANDO recarregar os eventos (a
/// cada troca de período), para nenhuma das visualizações precisar se
/// preocupar com isso.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime? _lastRangeStart;
  DateTime? _lastRangeEnd;
  bool _visaoLista = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authNotifierProvider).user?.id;
      if (userId == null) return;
      ref.read(calendarNotifierProvider.notifier).load(userId);
      ref.read(taskNotifierProvider.notifier).load(userId);
      _reloadEventsForCurrentRange(userId);
    });
  }

  /// Na visão Lista, o período é sempre o mês inteiro (é o que
  /// [UnifiedAgendaListView] mostra), não o que [CalendarUiState.viewMode]
  /// diria — senão trocar pra Lista vindo do modo Dia/Semana deixaria a
  /// lista incompleta até a próxima navegação.
  void _reloadEventsForCurrentRange(String userId) {
    final uiState = ref.read(calendarUiNotifierProvider);
    final range = _visaoLista
        ? (
            start: DateTime(uiState.focusedDate.year, uiState.focusedDate.month, 1),
            end: DateTime(uiState.focusedDate.year, uiState.focusedDate.month + 1, 1),
          )
        : ref.read(calendarUiNotifierProvider.notifier).visibleRange;
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _AlternadorTopo(
                visaoLista: _visaoLista,
                onChanged: (v) {
                  setState(() => _visaoLista = v);
                  if (userId != null) _reloadEventsForCurrentRange(userId);
                },
              ),
            ),
            if (_visaoLista) ...[
              _ListaHeader(
                title: DateFormatting.mesAno(uiState.focusedDate),
                onPrevious: notifier.goToPrevious,
                onNext: notifier.goToNext,
                onToday: notifier.goToToday,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: userId == null
                      ? const SizedBox.shrink()
                      : UnifiedAgendaListView(focusedDate: uiState.focusedDate, userId: userId),
                ),
              ),
            ] else ...[
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

/// Alternador Lista/Calendário no topo da tela — mesma cara do seletor de
/// modos que já existe dentro de [CalendarHeader], mas numa camada acima
/// (decide entre a lista unificada e o calendário inteiro, com seus
/// próprios 4 modos).
class _AlternadorTopo extends StatelessWidget {
  final bool visaoLista;
  final ValueChanged<bool> onChanged;

  const _AlternadorTopo({required this.visaoLista, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _opcao(label: 'Lista', selecionado: visaoLista, onTap: () => onChanged(true))),
          Expanded(child: _opcao(label: 'Calendário', selecionado: !visaoLista, onTap: () => onChanged(false))),
        ],
      ),
    );
  }

  Widget _opcao({required String label, required bool selecionado, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? AppColors.surfaceLight : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selecionado
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMuted.copyWith(
            color: selecionado ? AppColors.primary : AppColors.textMuted,
            fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho enxuto da visão "Lista": título do mês + navegação. Sem o
/// seletor de modos (dia/semana/mês/lista) — esse continua só dentro de
/// "Calendário", que é o que ele controla.
class _ListaHeader extends StatelessWidget {
  final String title;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _ListaHeader({required this.title, required this.onPrevious, required this.onNext, required this.onToday});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(title, key: ValueKey(title), style: AppTextStyles.heading2),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Anterior',
            color: AppColors.textMuted,
            onPressed: onPrevious,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onToday,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Hoje'),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Próximo',
            color: AppColors.textMuted,
            onPressed: onNext,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

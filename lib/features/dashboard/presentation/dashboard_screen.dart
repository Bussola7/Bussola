import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/domain/services/calendar_service.dart';
import 'package:bussola/features/agenda/presentation/providers/category_provider.dart';
import 'package:bussola/features/agenda/presentation/screens/event_editor_screen.dart';
import 'package:bussola/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:bussola/features/dashboard/presentation/widgets/dashboard_search_field.dart';
import 'package:bussola/features/dashboard/presentation/widgets/focus_chip.dart';
import 'package:bussola/features/dashboard/presentation/widgets/insight_banner.dart';
import 'package:bussola/features/dashboard/presentation/widgets/life_areas_row.dart';
import 'package:bussola/features/dashboard/presentation/widgets/next_appointment_card.dart';
import 'package:bussola/features/dashboard/presentation/widgets/performance_summary_card.dart';
import 'package:bussola/features/dashboard/presentation/widgets/quick_actions_row.dart';
import 'package:bussola/features/dashboard/presentation/widgets/today_tasks_section.dart';
import 'package:bussola/features/goals/presentation/providers/goal_provider.dart';
import 'package:bussola/features/goals/presentation/widgets/goal_form_sheet.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/features/tasks/presentation/widgets/task_form_sheet.dart';
import 'package:bussola/shared/models/life_area.dart';

/// Tela "Hoje": primeira tela que a pessoa vê depois de logada. Funciona
/// como um hub — header, próximo compromisso, busca, o bloco "Criar" e
/// as áreas da vida — em vez de listar tarefas/prioridades (isso mora
/// nas abas de sempre, todas fixas na navegação inferior).
class DashboardScreen extends ConsumerStatefulWidget {
  final String nomeUsuario;
  final String userId;

  /// Troca de aba a partir da Hoje (usado pelo menu de "Áreas da vida",
  /// que precisa abrir Agenda/Tarefas/Objetivos já com um filtro).
  final void Function(int index, {LifeArea? filtro})? onNavigateToTab;

  const DashboardScreen({
    super.key,
    required this.nomeUsuario,
    required this.userId,
    this.onNavigateToTab,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _calendarService = CalendarService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Tarefas/objetivos alimentam o resumo de "Relatórios"; categorias
      // são usadas pelo card de próximo compromisso.
      ref.read(taskNotifierProvider.notifier).load(widget.userId);
      ref.read(goalNotifierProvider.notifier).load(widget.userId);
      ref.read(categoryNotifierProvider.notifier).load(widget.userId);
    });
  }

  Future<void> _abrirCriar() async {
    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Nova tarefa'),
              onTap: () => Navigator.of(context).pop('tarefa'),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Novo compromisso'),
              onTap: () => Navigator.of(context).pop('compromisso'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Nova meta'),
              onTap: () => Navigator.of(context).pop('meta'),
            ),
          ],
        ),
      ),
    );
    if (escolha == null || !mounted) return;

    switch (escolha) {
      case 'tarefa':
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => TaskFormSheet(userId: widget.userId),
        );
        break;
      case 'meta':
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => GoalFormSheet(userId: widget.userId),
        );
        break;
      case 'compromisso':
        final calendar = await _calendarService.getOrCreateDefaultCalendar(widget.userId);
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EventEditorScreen(calendarId: calendar.id, userId: widget.userId, initialDate: DateTime.now()),
        ));
        break;
    }
  }

  void _verRelatorios() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relatórios', style: AppTextStyles.heading2),
            const SizedBox(height: 16),
            PerformanceSummaryCard(userId: widget.userId),
          ],
        ),
      ),
    );
  }

  Future<void> _escolherAreaDestino(LifeArea area) async {
    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Ver ${area.label} em', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Tarefas'),
              onTap: () => Navigator.of(context).pop('tarefas'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Agenda'),
              onTap: () => Navigator.of(context).pop('agenda'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Objetivos'),
              onTap: () => Navigator.of(context).pop('objetivos'),
            ),
          ],
        ),
      ),
    );
    if (escolha == null) return;

    switch (escolha) {
      case 'tarefas':
        widget.onNavigateToTab?.call(2, filtro: area);
        break;
      case 'agenda':
        widget.onNavigateToTab?.call(1, filtro: area);
        break;
      case 'objetivos':
        widget.onNavigateToTab?.call(3, filtro: area);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardHeader(nomeUsuario: widget.nomeUsuario),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InsightBanner(userId: widget.userId),
                const SizedBox(height: 12),
                NextAppointmentCard(userId: widget.userId),
                const SizedBox(height: 16),
                const DashboardSearchField(),
                const SizedBox(height: 12),
                FocusChip(userId: widget.userId),
                const SizedBox(height: 16),
                TodayTasksSection(userId: widget.userId),
                const SizedBox(height: 24),
                QuickActionsRow(onCriar: _abrirCriar, onRelatorios: _verRelatorios),
                const SizedBox(height: 24),
                Text('Áreas da vida', style: AppTextStyles.heading2),
                const SizedBox(height: 16),
                LifeAreasRow(onTapArea: _escolherAreaDestino),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

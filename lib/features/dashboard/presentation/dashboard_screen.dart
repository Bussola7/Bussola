import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/presentation/providers/category_provider.dart';
import 'package:bussola/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:bussola/features/dashboard/presentation/widgets/dashboard_search_field.dart';
import 'package:bussola/features/dashboard/presentation/widgets/focus_chip.dart';
import 'package:bussola/features/dashboard/presentation/widgets/life_areas_row.dart';
import 'package:bussola/features/dashboard/presentation/widgets/next_appointment_card.dart';
import 'package:bussola/features/dashboard/presentation/widgets/performance_summary_card.dart';
import 'package:bussola/features/dashboard/presentation/widgets/quick_actions_row.dart';
import 'package:bussola/features/goals/presentation/providers/goal_provider.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/features/tasks/presentation/screens/tasks_screen.dart';
import 'package:bussola/features/tasks/presentation/widgets/task_form_sheet.dart';

/// Tela "Hoje": primeira tela que a pessoa vê depois de logada. Funciona
/// como um hub — header com atalhos, próximo compromisso, busca, ações
/// rápidas e as áreas da vida — em vez de listar tarefas/prioridades
/// (isso mora agora na aba Tarefas, um toque de distância pelo atalho).
class DashboardScreen extends ConsumerStatefulWidget {
  final String nomeUsuario;
  final String userId;
  final ValueChanged<int>? onNavigateToTab;

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

  // Tarefas não é mais uma aba própria da navegação inferior (só Início,
  // Agenda e Metas são) — o atalho do header abre a tela por cima, como
  // já acontece com o Perfil.
  void _abrirTarefas() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TasksScreen()));
  void _abrirAgenda() => widget.onNavigateToTab?.call(1);
  void _abrirMetas() => widget.onNavigateToTab?.call(2);

  Future<void> _novaTarefa() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskFormSheet(userId: widget.userId),
    );
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardHeader(
            nomeUsuario: widget.nomeUsuario,
            onTapTarefas: _abrirTarefas,
            onTapMetas: _abrirMetas,
            onTapAgenda: _abrirAgenda,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NextAppointmentCard(userId: widget.userId),
                const SizedBox(height: 16),
                const DashboardSearchField(),
                const SizedBox(height: 12),
                const FocusChip(),
                const SizedBox(height: 20),
                QuickActionsRow(onNovaTarefa: _novaTarefa, onRelatorios: _verRelatorios),
                const SizedBox(height: 24),
                Text('Áreas da vida', style: AppTextStyles.heading2),
                const SizedBox(height: 16),
                LifeAreasRow(userId: widget.userId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

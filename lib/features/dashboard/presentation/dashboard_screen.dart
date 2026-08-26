import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/presentation/widgets/priority_badge.dart';
import 'package:bussola/features/dashboard/domain/dashboard_calculator.dart';
import 'package:bussola/features/dashboard/presentation/widgets/next_action_card.dart';
import 'package:bussola/features/dashboard/presentation/widgets/north_of_day_card.dart';
import 'package:bussola/features/dashboard/presentation/widgets/performance_summary_card.dart';
import 'package:bussola/features/goals/presentation/providers/goal_provider.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/features/voice/presentation/widgets/voice_command_button.dart';
import 'package:bussola/shared/widgets/life_area_badge.dart';

/// Tela "Hoje": primeira tela que a pessoa vê depois de logada.
///
/// Mostra, com dados reais (nada simulado): o resumo "Norte do Dia",
/// uma sugestão de próxima ação, um resumo de desempenho (Performance
/// não é mais aba própria), até 3 prioridades do dia, tarefas do dia e
/// tarefas atrasadas.
class DashboardScreen extends ConsumerStatefulWidget {
  final String nomeUsuario;
  final String userId;
  final VoidCallback? onAbrirPerfil;
  final ValueChanged<int>? onNavigateToTab;

  const DashboardScreen({
    super.key,
    required this.nomeUsuario,
    required this.userId,
    this.onAbrirPerfil,
    this.onNavigateToTab,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _calculator = DashboardCalculator();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskNotifierProvider.notifier).load(widget.userId);
      ref.read(goalNotifierProvider.notifier).load(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskNotifierProvider);
    final prioridades = _calculator.prioridades(taskState.tasks);
    final tarefasHoje = taskState.hoje;
    final atrasadas = taskState.atrasadas;
    final concluidasHoje = _calculator.concluidasHoje(taskState.tasks);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 24, backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bom dia, ${widget.nomeUsuario} \u{1F44B}', style: AppTextStyles.heading2),
                    Text(_calculator.formatarData(DateTime.now()), style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
              VoiceCommandButton(userId: widget.userId),
              if (widget.onAbrirPerfil != null)
                IconButton(onPressed: widget.onAbrirPerfil, icon: const Icon(Icons.person_outline)),
            ],
          ),
          const SizedBox(height: 24),
          NorthOfDayCard(userId: widget.userId),
          const SizedBox(height: 16),
          NextActionCard(userId: widget.userId, onNavigateToTab: widget.onNavigateToTab),
          const SizedBox(height: 16),
          PerformanceSummaryCard(userId: widget.userId),
          const SizedBox(height: 24),

          if (atrasadas.isNotEmpty) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 6),
                      Text('${atrasadas.length} tarefa${atrasadas.length == 1 ? '' : 's'} atrasada${atrasadas.length == 1 ? '' : 's'}',
                          style: AppTextStyles.body.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...atrasadas.take(3).map((t) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• ${t.title}', style: AppTextStyles.bodyMuted),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Text('Prioridades', style: AppTextStyles.heading2),
          const SizedBox(height: 8),
          if (prioridades.isEmpty)
            Text('Nenhuma tarefa pendente — bom trabalho! \u{1F389}', style: AppTextStyles.bodyMuted)
          else
            ...prioridades.map((t) => _ResumoTile(task: t)),

          const SizedBox(height: 20),
          Text('Tarefas de hoje', style: AppTextStyles.heading2),
          const SizedBox(height: 8),
          if (tarefasHoje.isEmpty)
            Text('Nenhuma tarefa com prazo para hoje.', style: AppTextStyles.bodyMuted)
          else
            ...tarefasHoje.map((t) => _ResumoTile(task: t)),

          const SizedBox(height: 20),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$concluidasHoje tarefa${concluidasHoje == 1 ? '' : 's'} concluída${concluidasHoje == 1 ? '' : 's'} hoje',
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumoTile extends StatelessWidget {
  final TaskModel task;

  const _ResumoTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            PriorityBadge(priority: task.priority),
            const SizedBox(width: 10),
            Expanded(child: Text(task.title, style: AppTextStyles.body)),
            const SizedBox(width: 8),
            LifeAreaBadge(area: task.area),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/presentation/providers/day_intelligence_provider.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/features/tasks/presentation/widgets/task_form_sheet.dart';
import 'package:bussola/features/tasks/presentation/widgets/task_tile.dart';

/// Tarefas com prazo hoje, na própria Hoje — pra marcar como concluída
/// sem precisar ir até a aba Tarefas. Quando o chip "Foco: [área]" está
/// visível (há um próximo compromisso com área definida), a lista já sai
/// filtrada por essa área via [focusAreaProvider]; sem foco, mostra todas
/// as tarefas de hoje.
class TodayTasksSection extends ConsumerWidget {
  final String userId;

  const TodayTasksSection({super.key, required this.userId});

  Future<void> _editar(BuildContext context, TaskModel tarefa) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskFormSheet(userId: userId, tarefaExistente: tarefa),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foco = ref.watch(focusAreaProvider(userId));
    final tarefas = ref.watch(taskNotifierProvider).tasks;
    final deHoje = tarefas.where((t) => t.isHoje).where((t) => foco == null || t.area == foco).toList()
      ..sort((a, b) => a.isConcluida == b.isConcluida ? 0 : (a.isConcluida ? 1 : -1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tarefas de hoje', style: AppTextStyles.heading2),
        const SizedBox(height: 12),
        if (deHoje.isEmpty)
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Expanded(child: Text('Nenhuma tarefa para hoje.', style: AppTextStyles.bodyMuted)),
              ],
            ),
          )
        else
          ...deHoje.map((t) => TaskTile(task: t, onTap: () => _editar(context, t))),
      ],
    );
  }
}

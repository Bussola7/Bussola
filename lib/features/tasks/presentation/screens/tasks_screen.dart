import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/empty_state.dart';
import 'package:bussola/core/components/loading_state.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/features/tasks/presentation/widgets/task_form_sheet.dart';
import 'package:bussola/shared/models/life_area.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authNotifierProvider).user?.id;
      if (userId != null) ref.read(taskNotifierProvider.notifier).load(userId);
    });
  }

  Future<void> _abrirFormulario({TaskModel? tarefaExistente}) async {
    final userId = ref.read(authNotifierProvider).user?.id;
    if (userId == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskFormSheet(userId: userId, tarefaExistente: tarefaExistente),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskNotifierProvider);
    final pendentes = state.pendentes;
    final concluidas = state.concluidas;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Tarefas'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: state.isLoading
          ? const LoadingState()
          : state.tasks.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Nenhuma tarefa ainda',
                  message: 'Toque no botão "+" para criar sua primeira tarefa.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  children: [
                    if (pendentes.isNotEmpty) ...[
                      Text('Pendentes (${pendentes.length})', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...pendentes.map((t) => _TaskTile(task: t, onTap: () => _abrirFormulario(tarefaExistente: t))),
                    ],
                    if (concluidas.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Concluídas (${concluidas.length})', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...concluidas.map((t) => _TaskTile(task: t, onTap: () => _abrirFormulario(tarefaExistente: t))),
                    ],
                  ],
                ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final TaskModel task;
  final VoidCallback onTap;

  const _TaskTile({required this.task, required this.onTap});

  Color _corPrioridade(Priority p) {
    switch (p) {
      case Priority.muitoAlta:
        return AppColors.error;
      case Priority.alta:
        return Colors.orange;
      case Priority.media:
        return AppColors.primary;
      case Priority.baixa:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => ref.read(taskNotifierProvider.notifier).delete(task.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        color: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          onTap: onTap,
          leading: GestureDetector(
            onTap: () => ref.read(taskNotifierProvider.notifier).toggleConcluida(task),
            child: Icon(
              task.isConcluida ? Icons.check_circle : Icons.radio_button_unchecked,
              color: task.isConcluida ? AppColors.secondary : _corPrioridade(task.priority),
            ),
          ),
          title: Text(
            task.title,
            style: AppTextStyles.body.copyWith(
              decoration: task.isConcluida ? TextDecoration.lineThrough : null,
              color: task.isConcluida ? AppColors.textMuted : null,
            ),
          ),
          subtitle: Row(
            children: [
              Text(task.area.emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(task.area.label, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
              if (task.dueDate != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.event_outlined,
                  size: 12,
                  color: task.isAtrasada ? AppColors.error : AppColors.textMuted,
                ),
                const SizedBox(width: 2),
                Text(
                  '${task.dueDate!.day.toString().padLeft(2, '0')}/${task.dueDate!.month.toString().padLeft(2, '0')}',
                  style: AppTextStyles.bodyMuted.copyWith(fontSize: 12, color: task.isAtrasada ? AppColors.error : null),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

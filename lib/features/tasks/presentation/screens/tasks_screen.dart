import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/empty_state.dart';
import 'package:bussola/core/components/loading_state.dart';
import 'package:bussola/core/components/screen_hint.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/features/tasks/presentation/widgets/task_form_sheet.dart';
import 'package:bussola/features/tasks/presentation/widgets/task_tile.dart';

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
      body: Column(
        children: [
          const ScreenHint(
            text: 'Aqui você organiza suas tarefas do dia a dia: pendências, afazeres e pequenas ações que '
                'precisam ser feitas — com prazo, prioridade e status de conclusão.',
          ),
          Expanded(
            child: state.isLoading
                ? const LoadingState()
                : state.tasks.isEmpty
                    ? const EmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'Nenhuma tarefa ainda',
                        message: 'Toque no botão "+" para criar sua primeira tarefa.',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        children: [
                          if (pendentes.isNotEmpty) ...[
                            Text('Pendentes (${pendentes.length})', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ...pendentes.map((t) => TaskTile(task: t, onTap: () => _abrirFormulario(tarefaExistente: t))),
                          ],
                          if (concluidas.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text('Concluídas (${concluidas.length})', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ...concluidas.map((t) => TaskTile(task: t, onTap: () => _abrirFormulario(tarefaExistente: t))),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

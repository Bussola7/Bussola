import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/empty_state.dart';
import 'package:bussola/core/components/loading_state.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/goals/data/models/goal_model.dart';
import 'package:bussola/features/goals/presentation/providers/goal_provider.dart';
import 'package:bussola/features/goals/presentation/widgets/goal_form_sheet.dart';
import 'package:bussola/shared/models/life_area.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authNotifierProvider).user?.id;
      if (userId != null) ref.read(goalNotifierProvider.notifier).load(userId);
    });
  }

  Future<void> _abrirFormulario({GoalModel? objetivoExistente}) async {
    final userId = ref.read(authNotifierProvider).user?.id;
    if (userId == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => GoalFormSheet(userId: userId, objetivoExistente: objetivoExistente),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(goalNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Objetivos'), backgroundColor: Colors.transparent, elevation: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: state.isLoading
          ? const LoadingState()
          : state.goals.isEmpty
              ? const EmptyState(
                  icon: Icons.flag_outlined,
                  title: 'Nenhum objetivo ainda',
                  message: 'Toque no botão "+" para definir seu primeiro objetivo.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  children: [
                    if (state.emAndamento.isNotEmpty) ...[
                      Text('Em andamento (${state.emAndamento.length})', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...state.emAndamento.map((g) => _GoalCard(goal: g, onTap: () => _abrirFormulario(objetivoExistente: g))),
                    ],
                    if (state.concluidos.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Concluídos (${state.concluidos.length})', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...state.concluidos.map((g) => _GoalCard(goal: g, onTap: () => _abrirFormulario(objetivoExistente: g))),
                    ],
                  ],
                ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final GoalModel goal;
  final VoidCallback onTap;

  const _GoalCard({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('${goal.area.emoji} ', style: const TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      goal.title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: goal.isConcluido ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (goal.isConcluido) const Icon(Icons.check_circle, color: AppColors.secondary, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: goal.progressPercent / 100,
                  minHeight: 8,
                  backgroundColor: AppColors.backgroundLight,
                  color: goal.isConcluido ? AppColors.secondary : AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${goal.progressPercent}%', style: AppTextStyles.bodyMuted),
                  if (goal.dueDate != null)
                    Text(
                      'até ${goal.dueDate!.day.toString().padLeft(2, '0')}/${goal.dueDate!.month.toString().padLeft(2, '0')}',
                      style: AppTextStyles.bodyMuted,
                    ),
                ],
              ),
              if (!goal.isConcluido) ...[
                const SizedBox(height: 4),
                Slider(
                  value: goal.progressPercent.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: AppColors.primary,
                  onChanged: (v) => ref.read(goalNotifierProvider.notifier).setProgress(goal, v.round()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

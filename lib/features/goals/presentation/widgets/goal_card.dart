import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/goals/data/models/goal_model.dart';
import 'package:bussola/features/goals/presentation/providers/goal_provider.dart';
import 'package:bussola/shared/models/life_area.dart';

/// Card de um objetivo — título, barra e % de progresso, prazo, e um
/// slider pra ajustar o progresso direto na lista. Usado na tela
/// Objetivos e na tela de detalhe de uma área de vida.
class GoalCard extends ConsumerWidget {
  final GoalModel goal;
  final VoidCallback onTap;

  const GoalCard({super.key, required this.goal, required this.onTap});

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

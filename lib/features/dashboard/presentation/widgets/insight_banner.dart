import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/dashboard/presentation/providers/insight_provider.dart';

/// Banner discreto com até 2 sugestões/insights sobre a rotina da pessoa
/// (tarefas atrasadas, dia cheio, área esquecida) — a base do que vai
/// ocupar o espaço do chat no futuro. Some inteiramente quando nenhuma
/// regra se aplica (dia tranquilo não precisa de aviso nenhum).
class InsightBanner extends ConsumerWidget {
  final String userId;

  const InsightBanner({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider(userId));
    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final insight in insights) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(insight.message, style: AppTextStyles.body.copyWith(fontSize: 13))),
              ],
            ),
          ),
          if (insight != insights.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

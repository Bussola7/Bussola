import 'package:flutter/material.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/presentation/widgets/bussola_fab.dart';

/// Duas ações rápidas lado a lado: criar tarefa e ver o resumo de
/// desempenho ("Relatórios" reaproveita o `PerformanceSummaryCard`/
/// `PerformanceCalculator` já existentes, só que numa folha em vez de
/// inline na tela).
class QuickActionsRow extends StatelessWidget {
  final VoidCallback onNovaTarefa;
  final VoidCallback onRelatorios;

  const QuickActionsRow({super.key, required this.onNovaTarefa, required this.onRelatorios});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            title: 'Nova tarefa',
            subtitle: 'Adicionar à trilha',
            onTap: onNovaTarefa,
            trailing: BussolaFab(onPressed: onNovaTarefa, tooltip: 'Nova tarefa'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            title: 'Relatórios',
            subtitle: 'Ver desempenho',
            onTap: onRelatorios,
            trailing: BussolaFab(
              onPressed: onRelatorios,
              tooltip: 'Relatórios',
              icon: Icons.bar_chart,
              color: AppColors.cardDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _QuickActionCard({required this.title, required this.subtitle, required this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          trailing,
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

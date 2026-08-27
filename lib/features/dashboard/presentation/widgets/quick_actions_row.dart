import 'package:flutter/material.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/presentation/widgets/bussola_fab.dart';

/// Duas ações rápidas lado a lado: "Criar" (tarefa/compromisso/meta, num
/// menu só) e "Relatórios" (reaproveita o `PerformanceSummaryCard`/
/// `PerformanceCalculator` já existentes, só que numa folha em vez de
/// inline na tela). Substituiu o antigo card "Nova tarefa" sozinho e o
/// "+" central da navegação — agora criar é um lugar só.
class QuickActionsRow extends StatelessWidget {
  final VoidCallback onCriar;
  final VoidCallback onRelatorios;

  const QuickActionsRow({super.key, required this.onCriar, required this.onRelatorios});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            title: 'Criar',
            subtitle: 'Tarefa, compromisso ou meta',
            onTap: onCriar,
            trailing: BussolaFab(onPressed: onCriar, tooltip: 'Criar'),
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
            mostrarSeta: true,
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
  final bool mostrarSeta;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.mostrarSeta = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              trailing,
              if (mostrarSeta) const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

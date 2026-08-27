import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/dashboard/domain/dashboard_calculator.dart';
import 'package:bussola/features/goals/presentation/providers/goal_provider.dart';
import 'package:bussola/features/performance/domain/performance_calculator.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';

/// Resumo de "Seu Desempenho" na tela Hoje — 3 números-chave em vez da
/// tela Performance inteira (que foi removida da navegação). Usa o mesmo
/// [PerformanceCalculator] que a tela antiga usava, só que resumido.
class PerformanceSummaryCard extends ConsumerWidget {
  final String userId;

  const PerformanceSummaryCard({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculator = PerformanceCalculator();
    final taskState = ref.watch(taskNotifierProvider);
    final goalState = ref.watch(goalNotifierProvider);

    // "Tarefas concluídas" é um resumo do DIA (concluídas hoje), não o
    // total histórico — senão o número só cresce e para de ser um sinal
    // útil de progresso diário.
    final concluidasHoje = DashboardCalculator().concluidasHoje(taskState.tasks);
    final prioridadesConcluidas = calculator.prioridadesConcluidas(taskState.tasks);
    final objetivosEmAndamento = goalState.emAndamento.length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seu Desempenho', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Metrica(icon: '\u{2705}', valor: '$concluidasHoje', rotulo: 'Tarefas concluídas hoje')),
              Expanded(child: _Metrica(icon: '\u{1F525}', valor: '$prioridadesConcluidas', rotulo: 'Prioridades concluídas')),
              Expanded(child: _Metrica(icon: '\u{1F3AF}', valor: '$objetivosEmAndamento', rotulo: 'Objetivos em andamento')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  final String icon;
  final String valor;
  final String rotulo;

  const _Metrica({required this.icon, required this.valor, required this.rotulo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(valor, style: AppTextStyles.heading2.copyWith(fontSize: 20)),
        const SizedBox(height: 2),
        Text(rotulo, style: AppTextStyles.bodyMuted.copyWith(fontSize: 11), maxLines: 2),
      ],
    );
  }
}

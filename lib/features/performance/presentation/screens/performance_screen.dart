import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/goals/presentation/providers/goal_provider.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';

/// Tela "Performance": indicadores simples de execução, calculados só a
/// partir de dados reais de Tarefas e Objetivos — nada simulado.
class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(authNotifierProvider).user?.id;
      if (userId == null) return;
      // Carrega os dois — a tela pode ser a primeira a ser aberta na
      // sessão, então não pode depender de outra tela ter carregado antes.
      ref.read(taskNotifierProvider.notifier).load(userId);
      ref.read(goalNotifierProvider.notifier).load(userId);
    });
  }

  /// Quantas tarefas de PRIORIDADE ALTA/MUITO ALTA foram concluídas —
  /// interpretação de "prioridades concluídas" pedida no briefing.
  int _prioridadesConcluidas(List<TaskModel> tasks) {
    return tasks.where((t) => t.isConcluida && (t.priority == Priority.alta || t.priority == Priority.muitoAlta)).length;
  }

  /// Tarefas concluídas em cada um dos últimos 7 dias (hoje incluso),
  /// para o gráfico simples de evolução semanal.
  List<int> _evolucaoSemanal(List<TaskModel> tasks) {
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    return List.generate(7, (i) {
      final dia = hojeSemHora.subtract(Duration(days: 6 - i));
      return tasks.where((t) {
        if (t.completedAt == null) return false;
        final c = t.completedAt!;
        return c.year == dia.year && c.month == dia.month && c.day == dia.day;
      }).length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskNotifierProvider);
    final goalState = ref.watch(goalNotifierProvider);

    final concluidas = taskState.concluidas.length;
    final atrasadas = taskState.atrasadas.length;
    final prioridadesConcluidas = _prioridadesConcluidas(taskState.tasks);
    final objetivosEmAndamento = goalState.emAndamento.length;
    final evolucao = _evolucaoSemanal(taskState.tasks);
    final maxEvolucao = evolucao.isEmpty ? 1 : (evolucao.reduce((a, b) => a > b ? a : b)).clamp(1, 999);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Performance'), backgroundColor: Colors.transparent, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _IndicatorCard(icon: '\u{2705}', label: 'Tarefas concluídas', value: '$concluidas')),
              const SizedBox(width: 12),
              Expanded(child: _IndicatorCard(icon: '⏰', label: 'Tarefas atrasadas', value: '$atrasadas', destaque: atrasadas > 0)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _IndicatorCard(icon: '\u{1F525}', label: 'Prioridades concluídas', value: '$prioridadesConcluidas')),
              const SizedBox(width: 12),
              Expanded(child: _IndicatorCard(icon: '\u{1F3AF}', label: 'Objetivos em andamento', value: '$objetivosEmAndamento')),
            ],
          ),
          const SizedBox(height: 24),
          Text('Evolução semanal', style: AppTextStyles.heading2),
          const SizedBox(height: 4),
          Text('Tarefas concluídas por dia, últimos 7 dias', style: AppTextStyles.bodyMuted),
          const SizedBox(height: 16),
          AppCard(
            child: SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final hoje = DateTime.now();
                  final dia = DateTime(hoje.year, hoje.month, hoje.day).subtract(Duration(days: 6 - i));
                  final rotulos = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
                  final altura = evolucao[i] == 0 ? 4.0 : 12.0 + (evolucao[i] / maxEvolucao) * 68.0;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${evolucao[i]}', style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
                      const SizedBox(height: 4),
                      Container(
                        width: 22,
                        height: altura,
                        decoration: BoxDecoration(
                          color: i == 6 ? AppColors.primary : AppColors.primary.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(rotulos[dia.weekday % 7], style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final bool destaque;

  const _IndicatorCard({required this.icon, required this.label, required this.value, this.destaque = false});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.heading1.copyWith(color: destaque ? AppColors.error : null)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodyMuted, maxLines: 2),
        ],
      ),
    );
  }
}

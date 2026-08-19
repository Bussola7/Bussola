import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/dashboard/presentation/widgets/day_statistics_card.dart';
import 'package:bussola/features/dashboard/presentation/widgets/north_of_day_card.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/shared/models/life_area.dart';

/// Tela "Hoje": primeira tela que a pessoa vê depois de logada.
///
/// Mostra, com dados reais (nada simulado): até 3 prioridades do dia,
/// tarefas do dia, compromissos do dia (via "Norte do Dia"/"Estatísticas",
/// que já usam a Agenda de verdade), tarefas atrasadas, e um resumo
/// simples da execução do dia.
class DashboardScreen extends ConsumerStatefulWidget {
  final String nomeUsuario;
  final String userId;
  final VoidCallback? onAbrirPerfil;

  const DashboardScreen({super.key, required this.nomeUsuario, required this.userId, this.onAbrirPerfil});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskNotifierProvider.notifier).load(widget.userId);
    });
  }

  /// As 3 tarefas pendentes de maior prioridade — não precisam ser "de
  /// hoje": são as 3 coisas mais importantes para a pessoa olhar primeiro.
  List<TaskModel> _prioridades(List<TaskModel> tasks) {
    final pendentes = tasks.where((t) => !t.isConcluida).toList();
    const ordem = {Priority.muitoAlta: 0, Priority.alta: 1, Priority.media: 2, Priority.baixa: 3};
    pendentes.sort((a, b) => ordem[a.priority]!.compareTo(ordem[b.priority]!));
    return pendentes.take(3).toList();
  }

  String _formatarData(DateTime data) {
    const meses = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    ];
    return '${data.day} de ${meses[data.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskNotifierProvider);
    final prioridades = _prioridades(taskState.tasks);
    final tarefasHoje = taskState.hoje;
    final atrasadas = taskState.atrasadas;
    final concluidasHoje = taskState.tasks.where((t) {
      if (t.completedAt == null) return false;
      final hoje = DateTime.now();
      return t.completedAt!.year == hoje.year && t.completedAt!.month == hoje.month && t.completedAt!.day == hoje.day;
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 24, backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bom dia, ${widget.nomeUsuario} \u{1F44B}', style: AppTextStyles.heading2),
                    Text(_formatarData(DateTime.now()), style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
              if (widget.onAbrirPerfil != null)
                IconButton(onPressed: widget.onAbrirPerfil, icon: const Icon(Icons.person_outline)),
            ],
          ),
          const SizedBox(height: 24),
          NorthOfDayCard(userId: widget.userId),
          const SizedBox(height: 16),
          DayStatisticsCard(userId: widget.userId),
          const SizedBox(height: 24),

          if (atrasadas.isNotEmpty) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 6),
                      Text('${atrasadas.length} tarefa${atrasadas.length == 1 ? '' : 's'} atrasada${atrasadas.length == 1 ? '' : 's'}',
                          style: AppTextStyles.body.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...atrasadas.take(3).map((t) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• ${t.title}', style: AppTextStyles.bodyMuted),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Text('Prioridades', style: AppTextStyles.heading2),
          const SizedBox(height: 8),
          if (prioridades.isEmpty)
            Text('Nenhuma tarefa pendente — bom trabalho! \u{1F389}', style: AppTextStyles.bodyMuted)
          else
            ...prioridades.map((t) => _ResumoTile(titulo: t.title, subtitulo: t.area.label)),

          const SizedBox(height: 20),
          Text('Tarefas de hoje', style: AppTextStyles.heading2),
          const SizedBox(height: 8),
          if (tarefasHoje.isEmpty)
            Text('Nenhuma tarefa com prazo para hoje.', style: AppTextStyles.bodyMuted)
          else
            ...tarefasHoje.map((t) => _ResumoTile(titulo: t.title, subtitulo: t.area.label)),

          const SizedBox(height: 20),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$concluidasHoje tarefa${concluidasHoje == 1 ? '' : 's'} concluída${concluidasHoje == 1 ? '' : 's'} hoje',
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumoTile extends StatelessWidget {
  final String titulo;
  final String subtitulo;

  const _ResumoTile({required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(titulo, style: AppTextStyles.body)),
            Text(subtitulo, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

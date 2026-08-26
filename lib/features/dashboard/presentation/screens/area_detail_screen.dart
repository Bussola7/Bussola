import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/presentation/providers/category_provider.dart';
import 'package:bussola/features/agenda/presentation/providers/event_provider.dart';
import 'package:bussola/features/agenda/presentation/widgets/event_card.dart';
import 'package:bussola/features/agenda/presentation/widgets/event_detail_sheet.dart';
import 'package:bussola/features/goals/data/models/goal_model.dart';
import 'package:bussola/features/goals/presentation/providers/goal_provider.dart';
import 'package:bussola/features/goals/presentation/widgets/goal_card.dart';
import 'package:bussola/features/goals/presentation/widgets/goal_form_sheet.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/features/tasks/presentation/widgets/task_form_sheet.dart';
import 'package:bussola/features/tasks/presentation/widgets/task_tile.dart';
import 'package:bussola/shared/models/life_area.dart';

/// Tela dedicada de uma área de vida: tarefas, compromissos e objetivos
/// filtrados por [area], num só lugar. Aberta a partir dos ícones de
/// "Áreas da vida" na Hoje. Reaproveita os mesmos cards/dados de
/// Tarefas, Agenda e Objetivos — nada de lógica nova de listagem.
class AreaDetailScreen extends ConsumerStatefulWidget {
  final LifeArea area;
  final String userId;

  const AreaDetailScreen({super.key, required this.area, required this.userId});

  @override
  ConsumerState<AreaDetailScreen> createState() => _AreaDetailScreenState();
}

class _AreaDetailScreenState extends ConsumerState<AreaDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskNotifierProvider.notifier).load(widget.userId);
      ref.read(goalNotifierProvider.notifier).load(widget.userId);
      ref.read(categoryNotifierProvider.notifier).load(widget.userId);
      // Compromissos não têm uma "página" natural como tarefas/objetivos
      // (sempre presos a uma data) — carrega uma janela ampla (30 dias
      // atrás até 180 à frente) pra essa lista fazer sentido sozinha,
      // sem depender de o usuário já ter navegado até a Agenda antes.
      final agora = DateTime.now();
      ref.read(eventNotifierProvider.notifier).loadPeriod(
            userId: widget.userId,
            start: agora.subtract(const Duration(days: 30)),
            end: agora.add(const Duration(days: 180)),
          );
    });
  }

  Future<void> _editarTarefa(TaskModel tarefa) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskFormSheet(userId: widget.userId, tarefaExistente: tarefa),
    );
  }

  Future<void> _editarObjetivo(GoalModel objetivo) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => GoalFormSheet(userId: widget.userId, objetivoExistente: objetivo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.area;

    final tarefas = ref.watch(taskNotifierProvider).tasks.where((t) => t.area == area).toList();
    final objetivos = ref.watch(goalNotifierProvider).goals.where((g) => g.area == area).toList();
    final eventos = ref.watch(eventNotifierProvider).events.where((e) => !e.isDeleted && e.lifeArea == area).toList()
      ..sort((a, b) => a.startDatetime.compareTo(b.startDatetime));

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: area.color,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(area.icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(area.label),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _Secao(
            titulo: 'Tarefas',
            vazio: tarefas.isEmpty,
            mensagemVazia: 'Nenhuma tarefa em ${area.label}.',
            children: tarefas.map((t) => TaskTile(task: t, onTap: () => _editarTarefa(t))).toList(),
          ),
          const SizedBox(height: 24),
          _Secao(
            titulo: 'Compromissos',
            vazio: eventos.isEmpty,
            mensagemVazia: 'Nenhum compromisso em ${area.label}.',
            children: eventos
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EventCard(event: e, onTap: () => EventDetailSheet.show(context, event: e, userId: widget.userId)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          _Secao(
            titulo: 'Objetivos',
            vazio: objetivos.isEmpty,
            mensagemVazia: 'Nenhum objetivo em ${area.label}.',
            children: objetivos.map((g) => GoalCard(goal: g, onTap: () => _editarObjetivo(g))).toList(),
          ),
        ],
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final bool vazio;
  final String mensagemVazia;
  final List<Widget> children;

  const _Secao({required this.titulo, required this.vazio, required this.mensagemVazia, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: AppTextStyles.heading2),
        const SizedBox(height: 8),
        if (vazio)
          Text(mensagemVazia, style: AppTextStyles.bodyMuted)
        else
          ...children,
      ],
    );
  }
}

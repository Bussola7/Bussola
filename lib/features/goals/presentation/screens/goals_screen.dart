import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/empty_state.dart';
import 'package:bussola/core/components/loading_state.dart';
import 'package:bussola/core/components/screen_hint.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/goals/data/models/goal_model.dart';
import 'package:bussola/features/goals/presentation/providers/goal_provider.dart';
import 'package:bussola/features/goals/presentation/widgets/goal_card.dart';
import 'package:bussola/features/goals/presentation/widgets/goal_form_sheet.dart';

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
      body: Column(
        children: [
          const ScreenHint(
            text: 'Aqui você define metas de médio e longo prazo — coisas que você quer alcançar com o tempo, '
                'acompanhando o progresso aos poucos. Diferente de Tarefas (ações pontuais) e Agenda '
                '(compromissos com horário), os Objetivos representam o que você está construindo.',
          ),
          Expanded(
            child: state.isLoading
                ? const LoadingState()
                : state.goals.isEmpty
                    ? const EmptyState(
                        icon: Icons.flag_outlined,
                        title: 'Nenhum objetivo ainda',
                        message: 'Toque no botão "+" para definir seu primeiro objetivo.',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        children: [
                          if (state.emAndamento.isNotEmpty) ...[
                            Text('Em andamento (${state.emAndamento.length})', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ...state.emAndamento.map((g) => GoalCard(goal: g, onTap: () => _abrirFormulario(objetivoExistente: g))),
                          ],
                          if (state.concluidos.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text('Concluídos (${state.concluidos.length})', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ...state.concluidos.map((g) => GoalCard(goal: g, onTap: () => _abrirFormulario(objetivoExistente: g))),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

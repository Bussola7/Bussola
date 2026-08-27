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
import 'package:bussola/shared/models/life_area.dart';
import 'package:bussola/shared/widgets/area_filter_chip.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  /// Filtro de área com que a tela abre — ex: vindo dos ícones de "Áreas
  /// da vida" na Hoje. O usuário pode limpar depois, dentro da própria tela.
  final LifeArea? filtroInicial;

  /// Avisa quem abriu a tela (o `HomeShell`) que o filtro foi limpo — sem
  /// isso, o `HomeShell` continua guardando o filtro antigo e o reaplica
  /// na próxima vez que essa aba for reconstruída (ex: ao trocar de aba
  /// e voltar), fazendo o filtro "limpo" reaparecer sozinho.
  final VoidCallback? onFiltroLimpo;

  const GoalsScreen({super.key, this.filtroInicial, this.onFiltroLimpo});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  LifeArea? _filtro;

  @override
  void initState() {
    super.initState();
    _filtro = widget.filtroInicial;
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
      builder: (_) => GoalFormSheet(userId: userId, objetivoExistente: objetivoExistente, areaInicial: _filtro),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(goalNotifierProvider);
    final filtro = _filtro;
    final objetivos = filtro == null ? state.goals : state.goals.where((g) => g.area == filtro).toList();
    final emAndamento = objetivos.where((g) => !g.isConcluido).toList();
    final concluidos = objetivos.where((g) => g.isConcluido).toList();

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
          if (filtro != null)
            AreaFilterChip(
              area: filtro,
              onLimpar: () {
                setState(() => _filtro = null);
                widget.onFiltroLimpo?.call();
              },
            ),
          Expanded(
            child: state.isLoading
                ? const LoadingState()
                : objetivos.isEmpty
                    ? EmptyState(
                        icon: Icons.flag_outlined,
                        title: filtro == null ? 'Nenhum objetivo ainda' : 'Nenhum objetivo em ${filtro.label}',
                        message: filtro == null
                            ? 'Toque no botão "+" para definir seu primeiro objetivo.'
                            : 'Toque no botão "+" para definir um objetivo nessa área.',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        children: [
                          if (emAndamento.isNotEmpty) ...[
                            Text('Em andamento (${emAndamento.length})', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ...emAndamento.map((g) => GoalCard(goal: g, onTap: () => _abrirFormulario(objetivoExistente: g))),
                          ],
                          if (concluidos.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text('Concluídos (${concluidos.length})', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            ...concluidos.map((g) => GoalCard(goal: g, onTap: () => _abrirFormulario(objetivoExistente: g))),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

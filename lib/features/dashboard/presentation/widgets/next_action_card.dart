import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/domain/services/day_summary_service.dart';
import 'package:bussola/features/agenda/presentation/providers/day_intelligence_provider.dart';

/// Abas do menu inferior que a sugestão pode abrir — índices de
/// `HomeShell` (Hoje=0, Tarefas=1, Agenda=2, Objetivos=3, Performance=4).
const _tabAgenda = 2;
const _tabTarefas = 1;

/// "Sugestão": próxima ação recomendada para o dia, calculada por regras
/// (via `DaySummaryService.nextAction`, o mesmo cálculo do Norte do Dia —
/// nada é buscado/computado de novo aqui). Fica escondido enquanto
/// carrega ou se a busca falhar, para não duplicar erro com o card azul.
class NextActionCard extends ConsumerWidget {
  final String userId;
  final ValueChanged<int>? onNavigateToTab;

  const NextActionCard({super.key, required this.userId, this.onNavigateToTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dayIntelligenceProvider(userId));

    return async.when(
      data: (data) {
        final acao = data.summary.nextAction;
        return AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bolt_outlined, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sugestão', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(acao.texto, style: AppTextStyles.body),
                    if (onNavigateToTab != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => onNavigateToTab!(
                            acao.destino == NextActionDestino.agenda ? _tabAgenda : _tabTarefas,
                          ),
                          child: Text(acao.rotuloBotao),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

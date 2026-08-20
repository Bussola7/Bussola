import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/presentation/providers/day_intelligence_provider.dart';

/// Cartão "\u{1F9ED} Norte do Dia": resumo do dia gerado só com regras de
/// negócio (contagens + tempo livre) — nenhuma chamada de IA. Lê o
/// resultado já calculado do `dayIntelligenceProvider`.
class NorthOfDayCard extends ConsumerWidget {
  final String userId;

  const NorthOfDayCard({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dayIntelligenceProvider(userId));

    return AppCard(
      child: async.when(
        data: (data) {
          final resumo = data.summary;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('\u{1F9ED} Norte do Dia', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text('Bom dia!', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _bullet('${resumo.eventCount} compromisso${resumo.eventCount == 1 ? '' : 's'}'),
              if (resumo.importantMeetingsCount > 0)
                _bullet('${resumo.importantMeetingsCount} reunião${resumo.importantMeetingsCount == 1 ? '' : 'ões'} importante${resumo.importantMeetingsCount == 1 ? '' : 's'}'),
              _bullet('${_formatDuration(resumo.freeDuration)} livres'),
              if (resumo.largestFreeInterval != null)
                _bullet('Maior intervalo livre: ${_formatDuration(resumo.largestFreeInterval!)}'),
              const SizedBox(height: 8),
              Text(resumo.closingRemark, style: AppTextStyles.bodyMuted.copyWith(fontStyle: FontStyle.italic)),
            ],
          );
        },
        loading: () => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
        error: (_, __) => Text('Não foi possível calcular o Norte do Dia agora.', style: AppTextStyles.bodyMuted),
      ),
    );
  }

  Widget _bullet(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text('•  $texto', style: AppTextStyles.body.copyWith(fontSize: 14)),
      );

  String _formatDuration(Duration d) {
    final horas = d.inHours;
    final minutos = d.inMinutes % 60;
    if (horas == 0) return '$minutos min';
    if (minutos == 0) return '${horas}h';
    return '${horas}h${minutos.toString().padLeft(2, '0')}';
  }
}

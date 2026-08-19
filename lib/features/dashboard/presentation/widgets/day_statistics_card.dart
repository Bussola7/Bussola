import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/presentation/providers/day_intelligence_provider.dart';

/// Cartão "\u{1F4CA} Estatísticas": eventos do dia, horas ocupadas/livres e
/// maior intervalo livre — lê o mesmo resultado já calculado que o
/// "Norte do Dia" usa (nenhum cálculo duplicado).
class DayStatisticsCard extends ConsumerWidget {
  final String userId;

  const DayStatisticsCard({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dayIntelligenceProvider(userId));

    return AppCard(
      child: async.when(
        data: (data) {
          final a = data.analysis;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('\u{1F4CA} Estatísticas', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat('Eventos', '${a.eventCount}'),
                  _stat('Ocupadas', _formatDuration(a.busyDuration)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat('Livres', _formatDuration(a.freeDuration)),
                  _stat('Maior intervalo', a.largestFreeInterval == null ? '—' : _formatDuration(a.largestFreeInterval!)),
                ],
              ),
            ],
          );
        },
        loading: () => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
        error: (_, __) => Text('Não foi possível carregar as estatísticas agora.', style: AppTextStyles.bodyMuted),
      ),
    );
  }

  Widget _stat(String label, String valor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor, style: AppTextStyles.heading2.copyWith(fontSize: 20, color: AppColors.primary)),
          Text(label, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final horas = d.inHours;
    final minutos = d.inMinutes % 60;
    if (horas == 0) return '$minutos min';
    if (minutos == 0) return '${horas}h';
    return '${horas}h${minutos.toString().padLeft(2, '0')}';
  }
}

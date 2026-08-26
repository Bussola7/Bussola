import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/presentation/providers/category_provider.dart';
import 'package:bussola/features/agenda/presentation/providers/day_intelligence_provider.dart';
import 'package:bussola/features/agenda/presentation/widgets/event_detail_sheet.dart';

/// Card branco de destaque com o próximo compromisso do dia — o primeiro
/// evento (não excluído, com horário) que ainda vai acontecer hoje. Lê o
/// mesmo `dayIntelligenceProvider` que o resto da Agenda já usa (nenhuma
/// busca nova).
class NextAppointmentCard extends ConsumerWidget {
  final String userId;

  const NextAppointmentCard({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dayIntelligenceProvider(userId));

    return async.when(
      data: (data) {
        final agora = DateTime.now();
        final futuros = data.events
            .where((e) => !e.isDeleted && !e.allDay && e.startDatetime.isAfter(agora))
            .toList()
          ..sort((a, b) => a.startDatetime.compareTo(b.startDatetime));

        if (futuros.isEmpty) {
          return AppCard(
            child: Row(
              children: [
                const Icon(Icons.event_available_outlined, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Nenhum compromisso pelo resto do dia.', style: AppTextStyles.bodyMuted),
                ),
              ],
            ),
          );
        }

        final proximo = futuros.first;
        final categoria = ref.watch(categoryNotifierProvider).byId(proximo.categoryId);
        final hora = proximo.startDatetime.toLocal();
        final horaTexto = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
        final subtitulo = ['Hoje', horaTexto, if (categoria != null) categoria.name].join(' · ');

        return AppCard(
          onTap: () => EventDetailSheet.show(context, event: proximo, userId: userId),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(proximo.title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitulo, style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 72, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

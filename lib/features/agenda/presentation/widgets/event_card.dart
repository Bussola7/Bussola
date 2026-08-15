import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/core/utils/color_parsing.dart';
import 'package:bussola/features/agenda/data/mappers/event_formatting.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/presentation/providers/category_provider.dart';
import 'package:bussola/features/agenda/presentation/widgets/priority_badge.dart';

/// Cartão de evento reutilizável. Mostra horário, título, local, duração
/// e os indicadores de categoria (cor + ícone) e prioridade — enxuto, com
/// bastante espaço em branco. A categoria é sempre buscada ao vivo pelo
/// `categoryId` (nunca cacheada no card) — assim, editar uma categoria
/// atualiza automaticamente todos os cards que a usam.
class EventCard extends ConsumerWidget {
  final EventModel event;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoria = ref.watch(categoryNotifierProvider).byId(event.categoryId);
    final corCategoria = categoria != null ? hexToColor(categoria.color) : AppColors.textMuted;
    final horario = EventFormatting.horario(event);
    final duracao = EventFormatting.duracao(event);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(color: corCategoria, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(horario, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
                    if (categoria != null) ...[
                      const SizedBox(width: 6),
                      Text(categoria.icon, style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(event.title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                if (event.location != null && event.location!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PriorityBadge(priority: event.priority),
              if (duracao.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(duracao, style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

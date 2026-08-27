import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/shared/models/life_area.dart';

/// Etiqueta compacta com o emoji e o nome de uma área de vida — usada em
/// listas onde itens de áreas diferentes aparecem juntos (ex: Dashboard),
/// para identificar a área de relance sem precisar abrir o item.
class LifeAreaBadge extends StatelessWidget {
  final LifeArea area;

  const LifeAreaBadge({super.key, required this.area});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(area.emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(area.label, style: AppTextStyles.bodyMuted.copyWith(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

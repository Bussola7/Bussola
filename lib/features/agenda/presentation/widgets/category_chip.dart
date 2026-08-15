import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/core/utils/color_parsing.dart';
import 'package:bussola/features/agenda/data/models/category_model.dart';

/// Identidade visual de uma categoria: emoji + nome, com a cor da
/// categoria no fundo (bem discreta). Usado no `EventCard`, no
/// `EventDetail`, no `EventEditor` e no seletor de categorias.
class CategoryChip extends StatelessWidget {
  final CategoryModel? category;
  final bool selected;
  final VoidCallback? onTap;

  const CategoryChip({super.key, required this.category, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cor = category != null ? hexToColor(category!.color) : AppColors.textMuted;
    final nome = category?.name ?? 'Sem categoria';
    final icone = category?.icon ?? '•';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cor.withOpacity(selected ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: selected ? Border.all(color: cor, width: 1.2) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icone, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(nome, style: AppTextStyles.bodyMuted.copyWith(fontSize: 13, color: cor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

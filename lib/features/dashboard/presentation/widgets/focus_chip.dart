import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';

/// Chip indicando um filtro de foco ativo. Nesta etapa é decorativo — o
/// app ainda não tem filtro por área de vida na Hoje, então o rótulo é
/// fixo em vez de refletir um filtro de verdade.
class FocusChip extends StatelessWidget {
  final String label;

  const FocusChip({super.key, this.label = 'Foco: Trabalho'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_alt_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

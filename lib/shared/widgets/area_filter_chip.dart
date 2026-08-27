import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/shared/models/life_area.dart';

/// Chip "Filtrando: [área] ×" — mostrado no topo de Tarefas/Agenda/
/// Objetivos quando a tela chegou com um filtro de área (ex: vindo dos
/// ícones de "Áreas da vida" na Hoje). Tocar no × limpa o filtro.
class AreaFilterChip extends StatelessWidget {
  final LifeArea area;
  final VoidCallback onLimpar;

  const AreaFilterChip({super.key, required this.area, required this.onLimpar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
          decoration: BoxDecoration(color: area.backgroundColor, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(area.emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                'Filtrando: ${area.label}',
                style: AppTextStyles.bodyMuted.copyWith(fontSize: 13, color: area.color, fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: onLimpar,
                icon: Icon(Icons.close, size: 16, color: area.color),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Limpar filtro',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

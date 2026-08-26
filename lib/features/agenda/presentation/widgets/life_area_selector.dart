import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/shared/models/life_area.dart';

/// Seletor de área de vida do evento — opcional, por isso tem uma opção
/// "Nenhuma" além das 5 áreas. Mesmo estilo visual do [PrioritySelector].
class LifeAreaSelector extends StatelessWidget {
  final LifeArea? value;
  final ValueChanged<LifeArea?> onChanged;

  const LifeAreaSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(area: null, label: 'Nenhuma'),
        for (final area in LifeArea.values) _chip(area: area, label: area.label),
      ],
    );
  }

  Widget _chip({required LifeArea? area, required String label}) {
    final isSelected = area == value;
    return InkWell(
      onTap: () => onChanged(area),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black.withOpacity(0.04) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.black26 : Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (area != null) ...[
              Text(area.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(label, style: AppTextStyles.bodyMuted.copyWith(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

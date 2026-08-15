import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/presentation/widgets/priority_badge.dart';

/// Seletor de prioridade: 4 opções lado a lado, cada uma só com o
/// pontinho colorido + label curto — discreto, sem badges grandes.
class PrioritySelector extends StatelessWidget {
  final Priority value;
  final ValueChanged<Priority> onChanged;

  const PrioritySelector({super.key, required this.value, required this.onChanged});

  static const _labels = {
    Priority.muitoAlta: 'Muito alta',
    Priority.alta: 'Alta',
    Priority.media: 'Média',
    Priority.baixa: 'Baixa',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Priority.values.map((p) {
        final isSelected = p == value;
        return InkWell(
          onTap: () => onChanged(p),
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
                PriorityBadge(priority: p),
                const SizedBox(width: 6),
                Text(_labels[p]!, style: AppTextStyles.bodyMuted.copyWith(fontSize: 13)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

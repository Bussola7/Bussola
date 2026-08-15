import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';

/// Pequeno indicador visual de prioridade, usado no [EventCard]. A cor
/// comunica o nível — não tem texto, para caber no card sem poluir.
class PriorityBadge extends StatelessWidget {
  final Priority priority;
  final bool showLabel;

  const PriorityBadge({super.key, required this.priority, this.showLabel = false});

  Color get _color {
    switch (priority) {
      case Priority.muitoAlta:
        return AppColors.error;
      case Priority.alta:
        return AppColors.accent;
      case Priority.media:
        return AppColors.primary;
      case Priority.baixa:
        return AppColors.textMuted;
    }
  }

  String get _label {
    switch (priority) {
      case Priority.muitoAlta:
        return 'Muito alta';
      case Priority.alta:
        return 'Alta';
      case Priority.media:
        return 'Média';
      case Priority.baixa:
        return 'Baixa';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );

    if (!showLabel) {
      return Tooltip(message: 'Prioridade $_label', child: dot);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 6),
        Text('Prioridade $_label', style: TextStyle(fontSize: 13, color: _color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

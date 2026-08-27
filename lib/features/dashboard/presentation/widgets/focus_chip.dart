import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/features/agenda/presentation/providers/day_intelligence_provider.dart';
import 'package:bussola/shared/models/life_area.dart';

/// Chip "Foco: [área]" — reflete a área do próximo compromisso do dia
/// (o mesmo que o [NextAppointmentCard] mostra), em vez de um rótulo
/// fixo. Se nenhum compromisso futuro tiver uma área definida, o chip
/// some — mostrar "Foco" sem nenhum dado real por trás seria decoração
/// vazia. Quando visível, filtra a seção "Tarefas de hoje" logo abaixo
/// (mesma área, via [focusAreaProvider]).
class FocusChip extends ConsumerWidget {
  final String userId;

  const FocusChip({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = ref.watch(focusAreaProvider(userId));
    if (area == null) return const SizedBox.shrink();
    return _Chip(area: area);
  }
}

class _Chip extends StatelessWidget {
  final LifeArea area;

  const _Chip({required this.area});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: area.backgroundColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(area.icon, size: 16, color: area.color),
          const SizedBox(width: 6),
          Text(
            'Foco: ${area.label}',
            style: TextStyle(color: area.color, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

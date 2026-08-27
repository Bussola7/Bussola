import 'package:flutter/material.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/domain/models/agenda_item.dart';

/// Card de um [AgendaItem] na visão "Lista" unificada — tarefa ou evento,
/// com a mesma cara, diferenciados pela etiqueta ("Tarefa"/"Horário") e
/// pela cor da barra lateral.
class AgendaItemTile extends StatelessWidget {
  final AgendaItem item;
  final VoidCallback? onTap;

  const AgendaItemTile({super.key, required this.item, this.onTap});

  Color get _corTipo => item.type == AgendaItemType.tarefa ? AppColors.secondary : AppColors.primary;

  String get _horarioTexto {
    if (item.horario == null) {
      return item.type == AgendaItemType.tarefa ? 'Sem horário' : 'Dia inteiro';
    }
    return '${item.horario!.hour.toString().padLeft(2, '0')}:${item.horario!.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
            decoration: BoxDecoration(color: _corTipo, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_horarioTexto, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: item.finalizado ? TextDecoration.lineThrough : null,
                    color: item.finalizado ? AppColors.textMuted : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _EtiquetaTipo(type: item.type, cor: _corTipo),
        ],
      ),
    );
  }
}

class _EtiquetaTipo extends StatelessWidget {
  final AgendaItemType type;
  final Color cor;

  const _EtiquetaTipo({required this.type, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: cor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        type == AgendaItemType.tarefa ? 'Tarefa' : 'Horário',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor),
      ),
    );
  }
}

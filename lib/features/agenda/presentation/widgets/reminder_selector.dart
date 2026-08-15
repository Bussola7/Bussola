import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';

/// Seleção de múltiplos lembretes para um evento. As 6 opções padrão são
/// checkboxes simples; "Personalizado" revela um campo numérico (minutos).
/// Nesta etapa só guarda a seleção — nenhuma notificação é agendada.
class ReminderSelection {
  final ReminderType type;
  final int minutesBefore;

  const ReminderSelection({required this.type, required this.minutesBefore});

  @override
  bool operator ==(Object other) =>
      other is ReminderSelection && other.type == type && other.minutesBefore == minutesBefore;

  @override
  int get hashCode => Object.hash(type, minutesBefore);
}

const Map<ReminderType, int> kReminderDefaultMinutes = {
  ReminderType.noHorario: 0,
  ReminderType.min5: 5,
  ReminderType.min15: 15,
  ReminderType.min30: 30,
  ReminderType.hora1: 60,
  ReminderType.dia1: 60 * 24,
};

const Map<ReminderType, String> kReminderLabels = {
  ReminderType.noHorario: 'No horário',
  ReminderType.min5: '5 minutos antes',
  ReminderType.min15: '15 minutos antes',
  ReminderType.min30: '30 minutos antes',
  ReminderType.hora1: '1 hora antes',
  ReminderType.dia1: '1 dia antes',
  ReminderType.personalizado: 'Personalizado',
};

class ReminderSelector extends StatefulWidget {
  final List<ReminderSelection> value;
  final ValueChanged<List<ReminderSelection>> onChanged;

  const ReminderSelector({super.key, required this.value, required this.onChanged});

  @override
  State<ReminderSelector> createState() => _ReminderSelectorState();
}

class _ReminderSelectorState extends State<ReminderSelector> {
  late final TextEditingController _customMinutesController = TextEditingController(
    text: _customSelection?.minutesBefore.toString() ?? '',
  );

  ReminderSelection? get _customSelection {
    final encontrados = widget.value.where((r) => r.type == ReminderType.personalizado);
    return encontrados.isEmpty ? null : encontrados.first;
  }

  bool _isChecked(ReminderType type) => widget.value.any((r) => r.type == type);

  void _toggle(ReminderType type) {
    final jaTem = _isChecked(type);
    if (jaTem) {
      widget.onChanged(widget.value.where((r) => r.type != type).toList());
    } else {
      final minutos = kReminderDefaultMinutes[type] ?? 0;
      widget.onChanged([...widget.value, ReminderSelection(type: type, minutesBefore: minutos)]);
    }
  }

  void _updateCustomMinutes(String text) {
    final minutos = int.tryParse(text) ?? 0;
    final semPersonalizado = widget.value.where((r) => r.type != ReminderType.personalizado).toList();
    if (minutos > 0) {
      widget.onChanged([...semPersonalizado, ReminderSelection(type: ReminderType.personalizado, minutesBefore: minutos)]);
    } else {
      widget.onChanged(semPersonalizado);
    }
  }

  @override
  void dispose() {
    _customMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opcoesPadrao = kReminderLabels.keys.where((t) => t != ReminderType.personalizado);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...opcoesPadrao.map((type) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _isChecked(type),
              onChanged: (_) => _toggle(type),
              dense: true,
              title: Text(kReminderLabels[type]!, style: AppTextStyles.body.copyWith(fontSize: 14)),
            )),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _customSelection != null,
          onChanged: (marcado) {
            if (marcado == true) {
              _updateCustomMinutes(_customMinutesController.text.isEmpty ? '10' : _customMinutesController.text);
            } else {
              widget.onChanged(widget.value.where((r) => r.type != ReminderType.personalizado).toList());
            }
          },
          dense: true,
          title: Text('Personalizado', style: AppTextStyles.body.copyWith(fontSize: 14)),
        ),
        if (_customSelection != null)
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _customMinutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    onChanged: _updateCustomMinutes,
                  ),
                ),
                const SizedBox(width: 8),
                Text('minutos antes', style: AppTextStyles.bodyMuted.copyWith(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_text_styles.dart';

/// Texto curto e fixo no topo de uma tela, explicando pra que ela serve —
/// pensado pra quem está usando o app pela primeira vez e ainda não sabe
/// diferenciar Tarefas/Agenda/Objetivos.
class ScreenHint extends StatelessWidget {
  final String text;

  const ScreenHint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Text(text, style: AppTextStyles.bodyMuted),
    );
  }
}

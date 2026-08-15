import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';

/// Estado vazio da Agenda — aparece quando não há nenhum evento no
/// período em foco. Textos fixos, pedidos nesta etapa.
class EmptyAgendaState extends StatelessWidget {
  const EmptyAgendaState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_available_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 20),
            Text('Sua agenda está livre.', style: AppTextStyles.heading2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Toque no botão + para criar seu primeiro compromisso.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

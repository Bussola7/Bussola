import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';

/// Exemplos de frases que o comando de voz reconhece — mostrado quando o
/// usuário toca no "?" ao lado do microfone, pra orientar como falar.
const _exemplos = [
  'Agendar reunião amanhã às 15h',
  'Marcar consulta com o dentista dia 20 às 10h',
  'Criar evento reunião com o time na sexta às 9h',
  'Agendar reunião hoje ao meio-dia',
  'Marcar compromisso daqui a 3 dias às 14h30',
];

class VoiceCommandHelpSheet extends StatelessWidget {
  const VoiceCommandHelpSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const VoiceCommandHelpSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_none, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Comando de voz', style: AppTextStyles.heading2),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Toque no microfone e diga algo como:',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: 16),
          ..._exemplos.map(
            (exemplo) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: AppTextStyles.body.copyWith(color: AppColors.primary)),
                  Expanded(child: Text('"$exemplo"', style: AppTextStyles.body)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Depois de ouvir, você ainda revisa título, data e hora antes de criar o evento de verdade.',
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }
}

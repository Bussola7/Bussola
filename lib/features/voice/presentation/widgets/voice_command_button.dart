import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/features/voice/domain/voice_command_parser.dart';
import 'package:bussola/features/voice/presentation/widgets/voice_command_help_sheet.dart';
import 'package:bussola/features/voice/presentation/widgets/voice_event_confirm_sheet.dart';

/// Botão global de comando de voz: ouve uma frase, interpreta por regras
/// (via [VoiceCommandParser]) e, se reconhecer um pedido de criar
/// evento/reunião, abre a tela de confirmação já preenchida. Some da tela
/// quando o navegador não suporta reconhecimento de fala.
class VoiceCommandButton extends StatefulWidget {
  final String userId;

  const VoiceCommandButton({super.key, required this.userId});

  @override
  State<VoiceCommandButton> createState() => _VoiceCommandButtonState();
}

class _VoiceCommandButtonState extends State<VoiceCommandButton> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _parser = VoiceCommandParser();
  bool _speechDisponivel = false;
  bool _ouvindo = false;

  @override
  void initState() {
    super.initState();
    _speech.initialize().then((disponivel) {
      if (mounted) setState(() => _speechDisponivel = disponivel);
    });
  }

  @override
  void dispose() {
    if (_ouvindo) _speech.stop();
    super.dispose();
  }

  Future<void> _alternarEscuta() async {
    if (_ouvindo) {
      await _speech.stop();
      if (mounted) setState(() => _ouvindo = false);
      return;
    }
    setState(() => _ouvindo = true);
    await _speech.listen(
      localeId: 'pt_BR',
      onResult: (resultado) {
        if (!resultado.finalResult) return;
        setState(() => _ouvindo = false);
        _processar(resultado.recognizedWords);
      },
    );
  }

  void _processar(String texto) {
    if (!mounted || texto.trim().isEmpty) return;

    final resultado = _parser.parse(texto);
    if (resultado.intent == VoiceIntent.desconhecido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não entendi o comando. Tente algo como "agendar reunião amanhã às 15h".')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => VoiceEventConfirmSheet(userId: widget.userId, resultado: resultado),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_speechDisponivel) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _alternarEscuta,
          tooltip: _ouvindo ? 'Parar' : 'Comando de voz',
          icon: Icon(_ouvindo ? Icons.mic : Icons.mic_none),
          color: _ouvindo ? AppColors.error : AppColors.primary,
        ),
        IconButton(
          onPressed: () => VoiceCommandHelpSheet.show(context),
          tooltip: 'Exemplos de comando de voz',
          icon: const Icon(Icons.help_outline),
          color: AppColors.textMuted,
        ),
      ],
    );
  }
}

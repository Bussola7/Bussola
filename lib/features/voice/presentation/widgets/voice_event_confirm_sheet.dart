import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/custom_text_field.dart';
import 'package:bussola/core/components/primary_button.dart';
import 'package:bussola/core/components/secondary_button.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/domain/entities/event_entity.dart';
import 'package:bussola/features/agenda/domain/services/calendar_service.dart';
import 'package:bussola/features/agenda/presentation/providers/calendar_provider.dart';
import 'package:bussola/features/agenda/presentation/providers/event_provider.dart';
import 'package:bussola/features/voice/domain/voice_command_parser.dart';

/// Tela de confirmação de um evento reconhecido por comando de voz — o
/// parser é só uma sugestão por regras: nada é criado até o usuário revisar
/// (e poder corrigir) título, data e hora aqui e tocar em "Confirmar".
class VoiceEventConfirmSheet extends ConsumerStatefulWidget {
  final String userId;
  final VoiceCommandResult resultado;

  const VoiceEventConfirmSheet({super.key, required this.userId, required this.resultado});

  @override
  ConsumerState<VoiceEventConfirmSheet> createState() => _VoiceEventConfirmSheetState();
}

class _VoiceEventConfirmSheetState extends ConsumerState<VoiceEventConfirmSheet> {
  final _calendarService = CalendarService();

  late final TextEditingController _tituloController;
  late DateTime _data;
  late TimeOfDay _hora;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.resultado.titulo ?? '');

    final agora = DateTime.now();
    _data = widget.resultado.data ?? DateTime(agora.year, agora.month, agora.day);
    final horaPadrao = agora.add(const Duration(hours: 1));
    _hora = TimeOfDay(hour: widget.resultado.hora ?? horaPadrao.hour, minute: widget.resultado.minuto ?? 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calendarNotifierProvider.notifier).load(widget.userId);
    });
  }

  @override
  void dispose() {
    _tituloController.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _escolherHora() async {
    final escolhida = await showTimePicker(
      context: context,
      initialTime: _hora,
      // Formato 24h fixo — é o que faz sentido pro usuário brasileiro,
      // independente do idioma/locale configurado no navegador.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (escolhida != null) setState(() => _hora = escolhida);
  }

  Future<String?> _resolverCalendarId() async {
    try {
      final calendar = await _calendarService.getOrCreateDefaultCalendar(widget.userId);
      if (ref.read(calendarNotifierProvider).calendars.isEmpty) {
        await ref.read(calendarNotifierProvider.notifier).load(widget.userId);
      }
      return calendar.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmar() async {
    if (_tituloController.text.trim().isEmpty) return;

    setState(() => _salvando = true);

    final calendarId = await _resolverCalendarId();
    if (calendarId == null) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível preparar um calendário para o evento.')),
      );
      return;
    }

    final inicio = DateTime(_data.year, _data.month, _data.day, _hora.hour, _hora.minute);
    final entity = EventEntity(
      title: _tituloController.text.trim(),
      startDatetime: inicio,
      endDatetime: inicio.add(const Duration(hours: 1)),
      allDay: false,
    );
    final sucesso = await ref
        .read(eventNotifierProvider.notifier)
        .createEvent(entity: entity, calendarId: calendarId, userId: widget.userId);

    if (!mounted) return;
    setState(() => _salvando = false);

    if (sucesso) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evento criado.')));
    } else {
      final erro = ref.read(eventNotifierProvider).errorMessage ?? 'Não foi possível criar o evento.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    }
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirmar evento', style: AppTextStyles.heading2),
            const SizedBox(height: 4),
            Text('Reconhecido por comando de voz — revise antes de criar.', style: AppTextStyles.bodyMuted),
            const SizedBox(height: 16),
            CustomTextField(label: 'Título', controller: _tituloController),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: SecondaryButton(label: _formatarData(_data), onPressed: _escolherData)),
                const SizedBox(width: 8),
                Expanded(child: SecondaryButton(label: _formatarHora(_hora), onPressed: _escolherHora)),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Confirmar e criar', isLoading: _salvando, onPressed: _confirmar),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatarHora(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:bussola/core/components/custom_text_field.dart';
import 'package:bussola/core/components/primary_button.dart';
import 'package:bussola/core/components/secondary_button.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/shared/models/life_area.dart';

/// Formulário único para criar ou editar uma tarefa — se [tarefaExistente]
/// for informado, o formulário abre preenchido e salva como edição.
class TaskFormSheet extends ConsumerStatefulWidget {
  final String userId;
  final TaskModel? tarefaExistente;

  const TaskFormSheet({super.key, required this.userId, this.tarefaExistente});

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late LifeArea _area;
  late Priority _priority;
  DateTime? _dueDate;
  bool _salvando = false;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechDisponivel = false;
  bool _ouvindo = false;

  bool get _editando => widget.tarefaExistente != null;

  @override
  void initState() {
    super.initState();
    final t = widget.tarefaExistente;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _area = t?.area ?? LifeArea.pessoal;
    _priority = t?.priority ?? Priority.media;
    _dueDate = t?.dueDate;

    _speech.initialize().then((disponivel) {
      if (mounted) setState(() => _speechDisponivel = disponivel);
    });
  }

  @override
  void dispose() {
    if (_ouvindo) _speech.stop();
    _titleController.dispose();
    _descriptionController.dispose();
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
        setState(() {
          _titleController.text = resultado.recognizedWords;
          _titleController.selection = TextSelection.collapsed(offset: _titleController.text.length);
          if (resultado.finalResult) _ouvindo = false;
        });
      },
    );
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) setState(() => _dueDate = escolhida);
  }

  Future<void> _salvar() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _salvando = true);

    final agora = DateTime.now();
    final notifier = ref.read(taskNotifierProvider.notifier);

    bool sucesso;
    if (_editando) {
      final atualizada = widget.tarefaExistente!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        area: _area,
        priority: _priority,
        dueDate: _dueDate,
        clearDueDate: _dueDate == null,
      );
      sucesso = await notifier.update(atualizada);
    } else {
      final nova = TaskModel(
        id: '',
        userId: widget.userId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        area: _area,
        priority: _priority,
        dueDate: _dueDate,
        createdAt: agora,
        updatedAt: agora,
      );
      sucesso = await notifier.create(nova);
    }

    if (!mounted) return;
    setState(() => _salvando = false);

    if (sucesso) {
      Navigator.of(context).pop();
    } else {
      final erro = ref.read(taskNotifierProvider).errorMessage ?? 'Não foi possível salvar a tarefa.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _excluir() async {
    await ref.read(taskNotifierProvider.notifier).delete(widget.tarefaExistente!.id);
    if (mounted) Navigator.of(context).pop();
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
            Text(_editando ? 'Editar tarefa' : 'Nova tarefa', style: AppTextStyles.heading2),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: CustomTextField(label: 'Título', controller: _titleController)),
                if (_speechDisponivel) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _alternarEscuta,
                    tooltip: _ouvindo ? 'Parar' : 'Ditar o título',
                    icon: Icon(_ouvindo ? Icons.mic : Icons.mic_none),
                    color: _ouvindo ? AppColors.error : AppColors.primary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            CustomTextField(label: 'Descrição (opcional)', controller: _descriptionController),
            const SizedBox(height: 16),
            Text('Área', style: AppTextStyles.bodyMuted),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: LifeArea.values.map((a) {
                return ChoiceChip(
                  label: Text('${a.emoji} ${a.label}'),
                  selected: _area == a,
                  onSelected: (_) => setState(() => _area = a),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Prioridade', style: AppTextStyles.bodyMuted),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: Priority.values.map((p) {
                return ChoiceChip(
                  label: Text(_labelPrioridade(p)),
                  selected: _priority == p,
                  onSelected: (_) => setState(() => _priority = p),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: _dueDate == null
                        ? 'Definir prazo'
                        : '${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.year}',
                    onPressed: _escolherData,
                  ),
                ),
                if (_dueDate != null)
                  IconButton(onPressed: () => setState(() => _dueDate = null), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: _editando ? 'Salvar' : 'Criar tarefa', isLoading: _salvando, onPressed: _salvar),
            if (_editando) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _excluir,
                child: Text('Excluir tarefa', style: AppTextStyles.body.copyWith(color: AppColors.error)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _labelPrioridade(Priority p) {
    switch (p) {
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
}

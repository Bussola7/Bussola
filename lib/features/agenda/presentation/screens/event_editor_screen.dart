import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/custom_text_field.dart';
import 'package:bussola/core/components/primary_button.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/core/utils/validators.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/data/models/reminder_model.dart';
import 'package:bussola/features/agenda/domain/entities/event_entity.dart';
import 'package:bussola/features/agenda/domain/usecases/check_event_conflicts_usecase.dart';
import 'package:bussola/features/agenda/presentation/providers/category_provider.dart';
import 'package:bussola/features/agenda/presentation/providers/event_provider.dart';
import 'package:bussola/features/agenda/presentation/widgets/category_chip.dart';
import 'package:bussola/features/agenda/presentation/widgets/category_picker_sheet.dart';
import 'package:bussola/features/agenda/presentation/widgets/collapsible_section.dart';
import 'package:bussola/features/agenda/presentation/widgets/priority_selector.dart';
import 'package:bussola/features/agenda/presentation/widgets/reminder_selector.dart';

/// Tela de criação/edição de evento — reorganizada na Etapa 2.3 para ser
/// simples por padrão: só Título, Data, Hora e Local aparecem de cara.
/// Categoria, prioridade, lembretes (e a descrição, que é conteúdo
/// opcional) ficam dentro de "Mais opções", recolhida por padrão.
///
/// Se [existing] for nulo, cria um evento novo; se vier preenchido, edita.
class EventEditorScreen extends ConsumerStatefulWidget {
  final EventModel? existing;
  final String calendarId;
  final String userId;
  final DateTime? initialDate;

  const EventEditorScreen({
    super.key,
    this.existing,
    required this.calendarId,
    required this.userId,
    this.initialDate,
  });

  @override
  ConsumerState<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends ConsumerState<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;

  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _allDay;
  late Priority _priority;
  String? _categoryId;
  List<ReminderSelection> _reminders = [];
  bool _isSaving = false;
  bool _carregandoLembretes = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _locationController = TextEditingController(text: existing?.location ?? '');

    final base = existing?.startDatetime ?? widget.initialDate ?? DateTime.now();
    _date = DateTime(base.year, base.month, base.day);
    _startTime = TimeOfDay.fromDateTime(existing?.startDatetime ?? DateTime(base.year, base.month, base.day, 9));
    _endTime = TimeOfDay.fromDateTime(existing?.endDatetime ?? DateTime(base.year, base.month, base.day, 10));
    _allDay = existing?.allDay ?? false;
    _priority = existing?.priority ?? Priority.media;
    _categoryId = existing?.categoryId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(categoryNotifierProvider.notifier).load(widget.userId);
      if (existing != null) {
        setState(() => _carregandoLembretes = true);
        final lembretes = await ref.read(eventRemindersProvider(existing.id).future);
        if (!mounted) return;
        setState(() {
          _reminders = lembretes
              .map((r) => ReminderSelection(type: r.type, minutesBefore: r.minutesBefore))
              .toList();
          _carregandoLembretes = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime date, TimeOfDay time) => DateTime(date.year, date.month, date.day, time.hour, time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked == null) return;
    setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  Future<void> _pickCategory() async {
    final categoryId = await CategoryPickerSheet.show(context, userId: widget.userId, selectedCategoryId: _categoryId);
    if (categoryId != null) setState(() => _categoryId = categoryId);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final start = _allDay ? DateTime(_date.year, _date.month, _date.day) : _combine(_date, _startTime);
    final end = _allDay ? DateTime(_date.year, _date.month, _date.day, 23, 59) : _combine(_date, _endTime);

    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O horário final não pode ser antes do inicial.')),
      );
      return;
    }

    if (!_allDay) {
      final conflitos = await CheckEventConflictsUseCase().execute(
        userId: widget.userId,
        candidateStart: start,
        candidateEnd: end,
        candidateAllDay: _allDay,
        ignoreEventId: widget.existing?.id,
      );

      if (conflitos.isNotEmpty && mounted) {
        final tituloConflitos = conflitos.map((e) => '• ${e.title}').join('\n');
        final continuar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Conflito de horário'),
            content: Text('Este horário coincide com:\n\n$tituloConflitos\n\nDeseja continuar mesmo assim?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Revisar horário')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Continuar')),
            ],
          ),
        );
        if (continuar != true) return;
      }
    }

    setState(() => _isSaving = true);

    final entity = EventEntity(
      id: widget.existing?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      startDatetime: start,
      endDatetime: end,
      allDay: _allDay,
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      categoryId: _categoryId,
      priority: _priority,
    );

    final reminderModels = _reminders
        .map((r) => ReminderModel(
              id: '',
              eventId: widget.existing?.id ?? '',
              minutesBefore: r.minutesBefore,
              type: r.type,
              createdAt: DateTime.now(),
            ))
        .toList();

    final notifier = ref.read(eventNotifierProvider.notifier);
    final bool success;
    if (_isEditing) {
      success = await notifier.updateEvent(
        current: widget.existing!,
        changes: entity,
        updatedByUserId: widget.userId,
        reminders: reminderModels,
      );
    } else {
      success = await notifier.createEvent(
        entity: entity,
        calendarId: widget.calendarId,
        userId: widget.userId,
        reminders: reminderModels,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Evento atualizado.' : 'Evento criado.')),
      );
    } else {
      final erro = ref.read(eventNotifierProvider).errorMessage ?? 'Não foi possível salvar o evento.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = ref.watch(categoryNotifierProvider).categories;
    final categoriaSelecionada = categorias.where((c) => c.id == _categoryId).isEmpty
        ? null
        : categorias.where((c) => c.id == _categoryId).first;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar compromisso' : 'Novo compromisso'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Campos principais (sempre visíveis) ---
                CustomTextField(
                  label: 'Título',
                  controller: _titleController,
                  validator: (v) => Validators.requiredField(v, message: 'Dê um título ao compromisso'),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _allDay,
                  onChanged: (v) => setState(() => _allDay = v),
                  title: Text('Evento de dia inteiro', style: AppTextStyles.body),
                ),
                const SizedBox(height: 4),
                _FieldTile(label: 'Data', value: _formatDate(_date), icon: Icons.calendar_today_outlined, onTap: _pickDate),
                if (!_allDay) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FieldTile(
                          label: 'Início',
                          value: _startTime.format(context),
                          icon: Icons.schedule_outlined,
                          onTap: () => _pickTime(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FieldTile(
                          label: 'Fim',
                          value: _endTime.format(context),
                          icon: Icons.schedule_outlined,
                          onTap: () => _pickTime(isStart: false),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                CustomTextField(label: 'Local', controller: _locationController),

                const SizedBox(height: 8),
                const Divider(height: 32),

                // --- "Mais opções" (recolhida por padrão) ---
                CollapsibleSection(
                  title: 'Mais opções',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomTextField(label: 'Descrição', controller: _descriptionController),
                      const SizedBox(height: 20),
                      Text('Categoria', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickCategory,
                        borderRadius: BorderRadius.circular(20),
                        child: CategoryChip(category: categoriaSelecionada),
                      ),
                      const SizedBox(height: 20),
                      Text('Prioridade', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      PrioritySelector(value: _priority, onChanged: (p) => setState(() => _priority = p)),
                      const SizedBox(height: 20),
                      Text('Lembretes', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      if (_carregandoLembretes)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else
                        ReminderSelector(value: _reminders, onChanged: (r) => setState(() => _reminders = r)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                PrimaryButton(
                  label: _isEditing ? 'Salvar alterações' : 'Criar compromisso',
                  isLoading: _isSaving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _FieldTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _FieldTile({required this.label, required this.value, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
                  Text(value, style: AppTextStyles.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

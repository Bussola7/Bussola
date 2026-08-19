import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/primary_button.dart';
import 'package:bussola/core/components/secondary_button.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/data/mappers/event_formatting.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/presentation/providers/category_provider.dart';
import 'package:bussola/features/agenda/presentation/providers/event_provider.dart';
import 'package:bussola/features/agenda/presentation/screens/event_editor_screen.dart';
import 'package:bussola/features/agenda/presentation/widgets/category_chip.dart';
import 'package:bussola/features/agenda/presentation/widgets/priority_badge.dart';
import 'package:bussola/features/agenda/presentation/widgets/reminder_selector.dart';

/// Modal de detalhes de um evento, aberto ao tocar num [EventCard].
/// Fluxo: Evento → Detalhes (aqui) → Editar (abre o [EventEditorScreen])
/// ou Excluir (pede confirmação e faz soft delete). Mostra categoria,
/// cor, ícone, prioridade e a lista de lembretes — espaço já reservado
/// (mas vazio) para participantes e recorrência, que ainda não existem.
class EventDetailSheet extends ConsumerWidget {
  final EventModel event;
  final String userId;

  const EventDetailSheet({super.key, required this.event, required this.userId});

  static Future<void> show(BuildContext context, {required EventModel event, required String userId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDetailSheet(event: event, userId: userId),
    );
  }

  Future<void> _confirmarExclusao(BuildContext context, WidgetRef ref) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir compromisso?'),
        content: Text('"${event.title}" será removido da sua agenda.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmou != true || !context.mounted) return;

    final sucesso = await ref.read(eventNotifierProvider.notifier).deleteEvent(
          eventId: event.id,
          deletedByUserId: userId,
        );

    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sucesso ? 'Compromisso excluído.' : 'Não foi possível excluir.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoria = ref.watch(categoryNotifierProvider).byId(event.categoryId);
    final lembretesAsync = ref.watch(eventRemindersProvider(event.id));

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.backgroundLight, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(event.title, style: AppTextStyles.heading2),
            const SizedBox(height: 8),
            Text(EventFormatting.horario(event), style: AppTextStyles.bodyMuted),
            if (event.location != null && event.location!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(event.location!, style: AppTextStyles.bodyMuted),
              ]),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                CategoryChip(category: categoria),
                const SizedBox(width: 8),
                PriorityBadge(priority: event.priority, showLabel: true),
              ],
            ),
            if (event.description != null && event.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(event.description!, style: AppTextStyles.body),
            ],
            const SizedBox(height: 20),
            Text('Lembretes', style: AppTextStyles.bodyMuted.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            lembretesAsync.when(
              data: (lembretes) => lembretes.isEmpty
                  ? Text('Nenhum lembrete configurado.', style: AppTextStyles.bodyMuted)
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: lembretes
                          .map((l) => Chip(
                                label: Text(kReminderLabels[l.type] ?? l.type.name, style: const TextStyle(fontSize: 12)),
                                backgroundColor: AppColors.backgroundLight,
                                side: BorderSide.none,
                              ))
                          .toList(),
                    ),
              loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => Text('Não foi possível carregar os lembretes.', style: AppTextStyles.bodyMuted),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Excluir',
                    icon: Icons.delete_outline,
                    onPressed: () => _confirmarExclusao(context, ref),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Editar',
                    icon: Icons.edit_outlined,
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => EventEditorScreen(
                          existing: event,
                          calendarId: event.calendarId,
                          userId: userId,
                        ),
                      ));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

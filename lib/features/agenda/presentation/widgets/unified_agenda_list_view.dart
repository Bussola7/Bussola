import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/core/utils/date_formatting.dart';
import 'package:bussola/features/agenda/domain/models/agenda_item.dart';
import 'package:bussola/features/agenda/domain/services/agenda_list_builder.dart';
import 'package:bussola/features/agenda/presentation/providers/event_provider.dart';
import 'package:bussola/features/agenda/presentation/widgets/agenda_item_tile.dart';
import 'package:bussola/features/agenda/presentation/widgets/empty_agenda_state.dart';
import 'package:bussola/features/agenda/presentation/widgets/event_detail_sheet.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';
import 'package:bussola/features/tasks/presentation/widgets/task_form_sheet.dart';

/// Visão "Lista" unificada da Agenda: tarefas e eventos do mês em foco,
/// juntos, agrupados por dia e ordenados por horário — cada item com uma
/// etiqueta indicando se é "Tarefa" ou "Horário".
///
/// Só lê o que já está carregado em [taskNotifierProvider]/
/// [eventNotifierProvider] — quem carrega é a tela que usa este widget
/// (mesmo contrato do [AgendaListView] já existente, que carrega eventos
/// por período mas não desenha nada sozinho).
class UnifiedAgendaListView extends ConsumerWidget {
  final DateTime focusedDate;
  final String userId;

  const UnifiedAgendaListView({super.key, required this.focusedDate, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskNotifierProvider);
    final eventState = ref.watch(eventNotifierProvider);

    if ((taskState.isLoading || eventState.isLoading) && taskState.tasks.isEmpty && eventState.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final inicioMes = DateTime(focusedDate.year, focusedDate.month, 1);
    final fimMes = DateTime(focusedDate.year, focusedDate.month + 1, 1);
    final porDia = AgendaListBuilder().build(
      tasks: taskState.tasks,
      events: eventState.events,
      start: inicioMes,
      end: fimMes,
    );

    if (porDia.isEmpty) {
      return const EmptyAgendaState();
    }

    final dias = porDia.keys.toList()..sort();

    return ListView.builder(
      key: const PageStorageKey('unified_agenda_list_view'),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: dias.length,
      itemBuilder: (context, index) {
        final dia = dias[index];
        final itensDoDia = porDia[dia]!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(DateFormatting.diaSemanaEData(dia), style: AppTextStyles.bodyMuted),
              ),
              ...itensDoDia.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AgendaItemTile(item: item, onTap: () => _abrir(context, item)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrir(BuildContext context, AgendaItem item) {
    if (item.type == AgendaItemType.tarefa) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => TaskFormSheet(userId: userId, tarefaExistente: item.task),
      );
    } else {
      EventDetailSheet.show(context, event: item.event!, userId: userId);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/core/utils/date_formatting.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/presentation/providers/event_provider.dart';
import 'package:bussola/features/agenda/presentation/widgets/empty_agenda_state.dart';
import 'package:bussola/features/agenda/presentation/widgets/event_card.dart';
import 'package:bussola/features/agenda/presentation/widgets/event_detail_sheet.dart';

/// Visualização "Lista": os eventos do período em foco, agrupados por dia.
/// Mostra o [EmptyAgendaState] quando não há nenhum. Quem carrega os
/// eventos é a `CalendarScreen` (via `EventNotifier.loadPeriod`) — esta
/// tela só lê o estado já carregado.
class AgendaListView extends ConsumerWidget {
  final DateTime focusedDate;
  final String userId;

  const AgendaListView({super.key, required this.focusedDate, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventNotifierProvider);

    if (state.isLoading && state.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.events.isEmpty) {
      return const EmptyAgendaState();
    }

    final porDia = <DateTime, List<EventModel>>{};
    for (final evento in state.events) {
      final dia = DateFormatting.apenasData(evento.startDatetime);
      porDia.putIfAbsent(dia, () => []).add(evento);
    }
    final dias = porDia.keys.toList()..sort();

    return ListView.builder(
      key: const PageStorageKey('agenda_list_view'),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: dias.length,
      itemBuilder: (context, index) {
        final dia = dias[index];
        final eventosDoDia = porDia[dia]!..sort((a, b) => a.startDatetime.compareTo(b.startDatetime));

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(DateFormatting.diaSemanaEData(dia), style: AppTextStyles.bodyMuted),
              ),
              ...eventosDoDia.map(
                (evento) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: EventCard(
                    event: evento,
                    onTap: () => EventDetailSheet.show(context, event: evento, userId: userId),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

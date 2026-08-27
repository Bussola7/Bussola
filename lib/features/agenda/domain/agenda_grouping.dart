import 'package:bussola/core/utils/date_formatting.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';

/// Agrupa eventos pelo dia LOCAL de início — nunca pelo dia em UTC puro,
/// senão um compromisso à noite (ou de madrugada) cai no cabeçalho de dia
/// errado na visão "Lista" da Agenda. Extraído da `AgendaListView` pra
/// ser testável sem precisar renderizar o widget.
class AgendaGrouping {
  static Map<DateTime, List<EventModel>> porDia(List<EventModel> eventos) {
    final porDia = <DateTime, List<EventModel>>{};
    for (final evento in eventos) {
      final dia = DateFormatting.apenasData(evento.startDatetime.toLocal());
      porDia.putIfAbsent(dia, () => []).add(evento);
    }
    return porDia;
  }
}

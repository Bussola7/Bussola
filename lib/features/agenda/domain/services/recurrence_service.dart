import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';

/// Uma ocorrência calculada de um evento recorrente — não é uma linha do
/// banco, é só o resultado do cálculo (por isso não tem `id` próprio).
class EventOccurrence {
  final EventModel baseEvent;
  final DateTime start;
  final DateTime end;

  const EventOccurrence({required this.baseEvent, required this.start, required this.end});
}

/// Calcula as ocorrências de um evento recorrente dentro de um período —
/// e só isso. Não salva nada no banco, não sabe nada de Supabase.
///
/// Design deliberado (evita "gerar milhares de registros"): a recorrência
/// nunca vira linhas na tabela `events`. Só o evento original (o "pai") é
/// salvo, com `recurrenceType` + `recurrenceUntil`/`recurrenceCount`. Toda
/// vez que a Agenda precisa mostrar um período (ex: um mês), este serviço
/// calcula, na hora, quais datas aquele evento cai dentro do período —
/// o resultado não é persistido, só usado para desenhar a tela.
class RecurrenceService {
  /// Máximo de ocorrências calculadas numa única chamada — trava de
  /// segurança contra recorrências sem fim configuradas por engano
  /// (ex: "diário" sem `recurrenceUntil` nem `recurrenceCount`).
  static const int maxOcorrenciasPorChamada = 366;

  List<EventOccurrence> occurrencesInRange({
    required EventModel event,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    if (!event.isRecurring) {
      final dentroDoPeriodo = event.startDatetime.isBefore(rangeEnd) && event.endDatetime.isAfter(rangeStart);
      return dentroDoPeriodo ? [EventOccurrence(baseEvent: event, start: event.startDatetime, end: event.endDatetime)] : [];
    }

    final duracao = event.endDatetime.difference(event.startDatetime);
    final ocorrencias = <EventOccurrence>[];

    DateTime inicioAtual = event.startDatetime;
    int contagem = 0;

    while (contagem < maxOcorrenciasPorChamada) {
      final fimDaJanela = event.recurrenceUntil;
      if (fimDaJanela != null && inicioAtual.isAfter(fimDaJanela)) break;

      final limiteDeQuantidade = event.recurrenceCount;
      if (limiteDeQuantidade != null && contagem >= limiteDeQuantidade) break;

      if (inicioAtual.isAfter(rangeEnd)) break;

      final fimAtual = inicioAtual.add(duracao);
      if (inicioAtual.isBefore(rangeEnd) && fimAtual.isAfter(rangeStart)) {
        ocorrencias.add(EventOccurrence(baseEvent: event, start: inicioAtual, end: fimAtual));
      }

      contagem++;
      inicioAtual = _proximaData(inicioAtual, event.recurrenceType);
    }

    return ocorrencias;
  }

  DateTime _proximaData(DateTime atual, RecurrenceType tipo) {
    switch (tipo) {
      case RecurrenceType.diario:
        return atual.add(const Duration(days: 1));
      case RecurrenceType.semanal:
        return atual.add(const Duration(days: 7));
      case RecurrenceType.quinzenal:
        return atual.add(const Duration(days: 14));
      case RecurrenceType.mensal:
        return DateTime(atual.year, atual.month + 1, atual.day, atual.hour, atual.minute);
      case RecurrenceType.anual:
        return DateTime(atual.year + 1, atual.month, atual.day, atual.hour, atual.minute);
      case RecurrenceType.personalizado:
      case RecurrenceType.nunca:
        return atual.add(const Duration(days: 7)); // fallback seguro; "personalizado" pleno fica para etapa futura
    }
  }

  /// "Cancelar a recorrência" é só isto: o evento pai volta a ser um
  /// evento único (`RecurrenceType.nunca`) — nenhuma ocorrência futura é
  /// calculada de novo a partir daqui, e nada precisa ser apagado do banco.
  EventModel cancelRecurrence(EventModel event) {
    return event.copyWith(recurrenceType: RecurrenceType.nunca);
  }
}

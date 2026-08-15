import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/domain/entities/remote_calendar_event.dart';

/// Representação mínima de um evento da Microsoft Graph Calendar API
/// (`/me/events`) que o Bússola precisa — objeto Dart tipado, para o
/// resto do código nunca lidar com `Map<String, dynamic>` cru vindo da
/// Microsoft.
class OutlookCalendarEvent {
  final String outlookId;
  final String title;
  final String? description;
  final String? location;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final bool cancelled;
  final DateTime updatedAt;

  /// Dados crus de recorrência do Graph (`pattern`/`range`), guardados
  /// sem interpretação aqui — quem decide como mapear para
  /// [RecurrenceType] é [OutlookCalendarMapper.mapRecurrence], para
  /// manter a lógica de perda de informação num único lugar auditável.
  final Map<String, dynamic>? recurrenceJson;

  const OutlookCalendarEvent({
    required this.outlookId,
    required this.title,
    this.description,
    this.location,
    required this.start,
    required this.end,
    required this.allDay,
    required this.cancelled,
    required this.updatedAt,
    this.recurrenceJson,
  });

  factory OutlookCalendarEvent.fromApiJson(Map<String, dynamic> json) {
    final startJson = json['start'] as Map<String, dynamic>;
    final endJson = json['end'] as Map<String, dynamic>;
    final allDay = json['isAllDay'] as bool? ?? false;

    // ESTRATÉGIA DE TIMEZONE (documentada — ver também o mapper abaixo):
    // por padrão, a Microsoft Graph SEMPRE devolve `start`/`end` em UTC
    // (`timeZone: "UTC"`) nas respostas de leitura, mesmo quando o evento
    // foi criado com outro fuso — confirmado na documentação pública e em
    // relatos da própria comunidade de desenvolvedores Microsoft. Isso só
    // muda se o cliente mandar o header `Prefer: outlook.timezone="..."`,
    // que este Data Source NUNCA envia, de propósito — significa que
    // NENHUMA tabela de conversão Windows↔IANA é necessária para LER
    // eventos: o valor de `dateTime` já é sempre um instante UTC.
    //
    // Eventos de dia inteiro (`isAllDay: true`) TAMBÉM chegam como
    // `dateTime`+`timeZone: "UTC"` (meia-noite UTC), não como uma "data
    // pura" (diferente do Google, que usa um campo `date` separado) — por
    // isso construímos a data direto em UTC a partir do ano/mês/dia da
    // string, mesmo cuidado já aplicado ao mapper do Google para não
    // deixar o fuso local do aparelho empurrar o dia para frente/trás.
    DateTime parseDataDoOutlook(Map<String, dynamic> campo) {
      final bruto = campo['dateTime'] as String;
      final semFracaoDeSegundoExtra = bruto.split('.').first; // Graph manda 7 casas decimais, DateTime.parse aceita, mas isolamos a data com segurança
      final instanteUtc = DateTime.parse('${semFracaoDeSegundoExtra}Z');
      if (allDay) {
        return DateTime.utc(instanteUtc.year, instanteUtc.month, instanteUtc.day);
      }
      return instanteUtc;
    }

    return OutlookCalendarEvent(
      outlookId: json['id'] as String,
      title: (json['subject'] as String?) ?? '(Sem título)',
      description: _extractBodyContent(json['body'] as Map<String, dynamic>?),
      location: (json['location'] as Map<String, dynamic>?)?['displayName'] as String?,
      start: parseDataDoOutlook(startJson),
      end: parseDataDoOutlook(endJson),
      allDay: allDay,
      cancelled: json['isCancelled'] as bool? ?? false,
      updatedAt: DateTime.parse('${(json['lastModifiedDateTime'] as String).split('.').first}Z'),
      recurrenceJson: json['recurrence'] as Map<String, dynamic>?,
    );
  }

  static String? _extractBodyContent(Map<String, dynamic>? body) {
    if (body == null) return null;
    final conteudo = body['content'] as String?;
    if (conteudo == null || conteudo.isEmpty) return null;
    return conteudo;
  }
}

/// Resultado de mapear a recorrência do Graph para o modelo do Bússola —
/// separa o valor mapeado da informação sobre se houve perda, para quem
/// chama decidir o que fazer com isso (hoje: só registrar no relatório
/// desta etapa; nenhuma persistência do aviso existe ainda).
class OutlookRecurrenceMapping {
  final RecurrenceType type;
  final DateTime? until;
  final int? count;
  final bool perdaDeInformacao;
  final String? motivoDaPerda;

  const OutlookRecurrenceMapping({
    required this.type,
    this.until,
    this.count,
    this.perdaDeInformacao = false,
    this.motivoDaPerda,
  });
}

/// Único ponto do sistema que sabe o formato específico da Microsoft
/// Graph Calendar API. Converte [EventModel] → JSON do Graph (para
/// criar/atualizar) e `OutlookCalendarEvent` → [RemoteCalendarEvent]
/// (formato genérico que o `CalendarSyncService` entende).
class OutlookCalendarMapper {
  OutlookCalendarMapper._();

  /// Bússola → Outlook (corpo da requisição de criação/atualização).
  ///
  /// ESTRATÉGIA DE TIMEZONE: ao contrário da leitura (sempre UTC vindo do
  /// Graph), na ESCRITA a Microsoft Graph aceita nomes IANA diretamente
  /// no campo `timeZone` (confirmado na documentação pública do recurso
  /// `dateTimeTimeZone` — "America/Sao_Paulo", "Europe/London" etc. estão
  /// na lista oficial de fusos aceitos) — por isso mandamos
  /// `event.timezone` (já IANA, mesmo campo que o Google usa) direto,
  /// sem nenhuma tabela de conversão.
  static Map<String, dynamic> toGraphApiJson(EventModel event) {
    Map<String, dynamic> dateField(DateTime data) {
      final base = event.allDay ? DateTime.utc(data.year, data.month, data.day) : data.toUtc();
      return {
        'dateTime': base.toIso8601String(),
        'timeZone': event.allDay ? 'UTC' : event.timezone,
      };
    }

    return {
      'subject': event.title,
      if (event.description != null) 'body': {'contentType': 'text', 'content': event.description},
      if (event.location != null) 'location': {'displayName': event.location},
      'start': dateField(event.startDatetime),
      // Convenção igual à do Google/iCalendar: o fim de um evento de dia
      // inteiro é EXCLUSIVO — precisa ser o dia seguinte à meia-noite.
      'end': dateField(event.allDay ? event.endDatetime.add(const Duration(days: 1)) : event.endDatetime),
      'isAllDay': event.allDay,
    };
  }

  /// Outlook → genérico. Converte o evento específico do Outlook para o
  /// tipo que o `CalendarSyncService` entende — [RemoteCalendarEvent].
  static RemoteCalendarEvent toRemoteCalendarEvent(OutlookCalendarEvent outlookEvent) {
    final recorrencia = mapRecurrence(outlookEvent.recurrenceJson);
    return RemoteCalendarEvent(
      externalId: outlookEvent.outlookId,
      title: outlookEvent.title,
      description: outlookEvent.description,
      location: outlookEvent.location,
      start: outlookEvent.start,
      end: outlookEvent.end,
      allDay: outlookEvent.allDay,
      status: outlookEvent.cancelled ? 'cancelled' : 'confirmed',
      updatedAt: outlookEvent.updatedAt,
      // Diferente do Google (que não informa nada — os 4 campos ficam
      // `null`), o Outlook SEMPRE informa algo aqui: `mapRecurrence(null)`
      // já devolve `RecurrenceType.nunca` explicitamente para eventos sem
      // recorrência. É essa distinção (`null` vs. `nunca`) que permite a
      // recorrência do Outlook alimentar o `EventModel` de verdade sem
      // quebrar o comportamento do Google — ver `RemoteCalendarEvent`.
      recurrenceType: recorrencia.type,
      recurrenceDetail: recorrencia.motivoDaPerda,
      recurrenceUntil: recorrencia.until,
      recurrenceCount: recorrencia.count,
    );
  }

  /// Mapeia a recorrência crua do Graph (`pattern`/`range`) para o modelo
  /// de recorrência do Bússola — só o que o Bússola já suporta
  /// ([RecurrenceType]: diário/semanal/quinzenal/mensal/anual/personalizado).
  ///
  /// O Graph representa recorrência de forma muito mais rica (dias da
  /// semana específicos, "toda 2ª terça-feira do mês", intervalos
  /// arbitrários) do que o Bússola modela hoje. Quando o padrão do Graph
  /// não cabe exatamente num dos 5 tipos conhecidos, mapeamos para
  /// `personalizado` e marcamos [OutlookRecurrenceMapping.perdaDeInformacao]
  /// como `true`, com o motivo explicado em [OutlookRecurrenceMapping.motivoDaPerda]
  /// — NUNCA inventamos uma correspondência aproximada silenciosa.
  static OutlookRecurrenceMapping mapRecurrence(Map<String, dynamic>? recurrenceJson) {
    if (recurrenceJson == null) {
      return const OutlookRecurrenceMapping(type: RecurrenceType.nunca);
    }

    final pattern = recurrenceJson['pattern'] as Map<String, dynamic>? ?? {};
    final range = recurrenceJson['range'] as Map<String, dynamic>? ?? {};
    final tipoGraph = pattern['type'] as String?;
    final intervalo = pattern['interval'] as int? ?? 1;
    final diasDaSemana = (pattern['daysOfWeek'] as List<dynamic>?)?.cast<String>();

    DateTime? until;
    int? count;
    final rangeType = range['type'] as String?;
    if (rangeType == 'endDate' && range['endDate'] != null) {
      until = DateTime.tryParse(range['endDate'] as String);
    } else if (rangeType == 'numbered' && range['numberOfOccurrences'] != null) {
      count = range['numberOfOccurrences'] as int;
    }

    RecurrenceType type;
    bool perda = false;
    String? motivo;

    if (tipoGraph == 'daily' && intervalo == 1) {
      type = RecurrenceType.diario;
    } else if (tipoGraph == 'weekly' && intervalo == 1 && (diasDaSemana == null || diasDaSemana.length <= 1)) {
      type = RecurrenceType.semanal;
    } else if (tipoGraph == 'weekly' && intervalo == 2 && (diasDaSemana == null || diasDaSemana.length <= 1)) {
      type = RecurrenceType.quinzenal;
    } else if (tipoGraph == 'absoluteMonthly' || tipoGraph == 'relativeMonthly') {
      type = RecurrenceType.mensal;
      if (intervalo != 1) {
        perda = true;
        motivo = 'Recorrência mensal a cada $intervalo meses — o Bússola só representa "todo mês" (intervalo 1); o intervalo real foi perdido.';
      }
      if (tipoGraph == 'relativeMonthly') {
        perda = true;
        motivo = (motivo == null ? '' : '$motivo ') +
            'Padrão "relativeMonthly" (ex: "toda 2ª terça-feira do mês") não é representável no Bússola — foi tratado como mensal simples, perdendo a regra exata do dia.';
      }
    } else if (tipoGraph == 'absoluteYearly' || tipoGraph == 'relativeYearly') {
      type = RecurrenceType.anual;
      if (tipoGraph == 'relativeYearly') {
        perda = true;
        motivo = 'Padrão "relativeYearly" não é representável no Bússola — foi tratado como anual simples, perdendo a regra exata do dia.';
      }
    } else if (tipoGraph == 'weekly') {
      // Semanal com mais de 1 dia da semana marcado (ex: "toda 2ª e 5ª")
      // ou intervalo diferente de 1/2 — o Bússola não modela "dias
      // específicos da semana" nem intervalos arbitrários.
      type = RecurrenceType.personalizado;
      perda = true;
      motivo = 'Padrão semanal com ${diasDaSemana?.length ?? 0} dia(s) da semana e/ou intervalo $intervalo não cabe em diário/semanal/quinzenal do Bússola — mapeado como personalizado, sem os dias específicos.';
    } else {
      type = RecurrenceType.personalizado;
      perda = true;
      motivo = 'Padrão de recorrência do Graph "$tipoGraph" desconhecido ou não suportado — mapeado como personalizado, sem a regra original.';
    }

    return OutlookRecurrenceMapping(type: type, until: until, count: count, perdaDeInformacao: perda, motivoDaPerda: motivo);
  }
}

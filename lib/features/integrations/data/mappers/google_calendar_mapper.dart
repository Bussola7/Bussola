import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/domain/entities/remote_calendar_event.dart';

/// Representação mínima de um "Google Event" (recurso da Google Calendar
/// API v3) que o Bússola precisa — não é o JSON cru, é já um objeto Dart
/// tipado, para o resto do código nunca precisar lidar com `Map<String, dynamic>`
/// solto vindo do Google.
class GoogleCalendarEvent {
  final String googleId;
  final String title;
  final String? description;
  final String? location;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String status; // "confirmed" | "tentative" | "cancelled" (vocabulário do Google)
  final DateTime updatedAt; // campo "updated" do Google — usado para "última alteração vence"

  const GoogleCalendarEvent({
    required this.googleId,
    required this.title,
    this.description,
    this.location,
    required this.start,
    required this.end,
    required this.allDay,
    required this.status,
    required this.updatedAt,
  });

  factory GoogleCalendarEvent.fromApiJson(Map<String, dynamic> json) {
    final startJson = json['start'] as Map<String, dynamic>;
    final endJson = json['end'] as Map<String, dynamic>;
    final allDay = startJson['date'] != null; // Google usa "date" (sem hora) para eventos de dia inteiro

    // Para eventos com hora, o Google manda um offset explícito (RFC 3339,
    // ex: "2026-08-01T09:00:00-03:00") — `DateTime.parse` já resolve isso
    // corretamente para o instante certo.
    //
    // Para eventos de DIA INTEIRO, o Google manda só a data ("2026-08-01",
    // sem hora nem fuso) — é uma data "pura", não um instante. Se isso for
    // interpretado com `DateTime.parse` puro, o Dart assume meia-noite no
    // FUSO LOCAL do aparelho/servidor, e uma conversão para UTC mais tarde
    // pode empurrar a data para o dia anterior ou seguinte (ex: um fuso
    // UTC+9 jogaria "01/08 00:00 local" para "31/07 15:00 UTC" — o evento
    // "muda de dia" sozinho). Por isso construímos a data direto em UTC,
    // com os mesmos ano/mês/dia que o Google mandou — sem depender de
    // qual fuso o app está rodando.
    DateTime parseDataDoGoogle(Map<String, dynamic> campo) {
      final comHora = campo['dateTime'] as String?;
      if (comHora != null) return DateTime.parse(comHora);

      final apenasData = campo['date'] as String; // formato "YYYY-MM-DD"
      final partes = apenasData.split('-').map(int.parse).toList();
      return DateTime.utc(partes[0], partes[1], partes[2]);
    }

    return GoogleCalendarEvent(
      googleId: json['id'] as String,
      title: (json['summary'] as String?) ?? '(Sem título)',
      description: json['description'] as String?,
      location: json['location'] as String?,
      start: parseDataDoGoogle(startJson),
      end: parseDataDoGoogle(endJson),
      allDay: allDay,
      status: (json['status'] as String?) ?? 'confirmed',
      updatedAt: DateTime.parse(json['updated'] as String),
    );
  }
}

/// Único ponto do sistema que sabe o formato específico da Google
/// Calendar API. Converte [EventModel] → JSON do Google (para
/// criar/atualizar) e `GoogleCalendarEvent` → [RemoteCalendarEvent]
/// (formato genérico que o `CalendarSyncService` entende). Nenhuma outra
/// camada — nem o `CalendarSyncService`, nem a UI — deve montar esse JSON
/// na mão nem conhecer o tipo `GoogleCalendarEvent`.
class GoogleCalendarMapper {
  GoogleCalendarMapper._();

  /// Bússola → Google (corpo da requisição de criação/atualização).
  static Map<String, dynamic> toGoogleApiJson(EventModel event) {
    final timeZone = event.timezone;

    Map<String, dynamic> dateField(DateTime data) {
      return event.allDay
          ? {'date': '${data.year.toString().padLeft(4, '0')}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}'}
          : {'dateTime': data.toUtc().toIso8601String(), 'timeZone': timeZone};
    }

    return {
      'summary': event.title,
      if (event.description != null) 'description': event.description,
      if (event.location != null) 'location': event.location,
      'start': dateField(event.startDatetime),
      'end': dateField(event.endDatetime),
      'status': event.status == EventStatus.cancelado ? 'cancelled' : 'confirmed',
    };
  }

  /// Google → genérico. Converte o evento específico do Google para o
  /// tipo que o `CalendarSyncService` entende — [RemoteCalendarEvent].
  /// Esta é a ÚNICA conversão Google→genérico do sistema; a conversão
  /// genérico→[EventModel] mora em `RemoteCalendarEvent.toEventModel`
  /// (compartilhada por qualquer provedor, não duplicada aqui).
  static RemoteCalendarEvent toRemoteCalendarEvent(GoogleCalendarEvent googleEvent) {
    return RemoteCalendarEvent(
      externalId: googleEvent.googleId,
      title: googleEvent.title,
      description: googleEvent.description,
      location: googleEvent.location,
      start: googleEvent.start,
      end: googleEvent.end,
      allDay: googleEvent.allDay,
      status: googleEvent.status,
      updatedAt: googleEvent.updatedAt,
      // Recorrência (Etapa 1.8): o Google Calendar também tem um campo de
      // recorrência (`recurrence`, formato RRULE/RFC 5545), mas este
      // mapper ainda não o interpreta — por isso os 4 parâmetros de
      // recorrência de `RemoteCalendarEvent` ficam de fora aqui (usam o
      // valor padrão `null`). Isso é INTENCIONAL e não uma regressão: com
      // `null`, `RemoteCalendarEvent.toEventModel` preserva a recorrência
      // local já existente, exatamente como acontecia antes desta etapa.
      // Interpretar RRULE do Google fica como trabalho futuro.
    );
  }
}

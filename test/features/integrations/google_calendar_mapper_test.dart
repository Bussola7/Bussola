import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/data/mappers/google_calendar_mapper.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';

Map<String, dynamic> _googleEventJson({
  required Map<String, dynamic> start,
  required Map<String, dynamic> end,
  String status = 'confirmed',
  String? location,
  String? description,
}) {
  return {
    'id': 'google-evt-1',
    'summary': 'Reunião de teste',
    if (description != null) 'description': description,
    if (location != null) 'location': location,
    'start': start,
    'end': end,
    'status': status,
    'updated': '2026-08-01T10:00:00Z',
  };
}

EventModel _buildLocalEvent({required DateTime start, required DateTime end, bool allDay = false}) {
  final now = DateTime.now();
  return EventModel(
    id: 'evt-1',
    calendarId: 'cal-1',
    userId: 'user-1',
    title: 'Evento local',
    startDatetime: start,
    endDatetime: end,
    timezone: 'America/Sao_Paulo',
    allDay: allDay,
    priority: Priority.media,
    status: EventStatus.confirmado,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('GoogleCalendarEvent.fromApiJson — evento normal (com hora e timezone)', () {
    test('mantém o instante correto vindo com offset de Brasília (-03:00)', () {
      final json = _googleEventJson(
        start: {'dateTime': '2026-08-01T09:00:00-03:00', 'timeZone': 'America/Sao_Paulo'},
        end: {'dateTime': '2026-08-01T10:00:00-03:00', 'timeZone': 'America/Sao_Paulo'},
        location: 'Sala 2',
        description: 'Pauta X',
      );

      final evento = GoogleCalendarEvent.fromApiJson(json);

      expect(evento.allDay, false);
      expect(evento.location, 'Sala 2');
      expect(evento.description, 'Pauta X');
      // 09:00 em -03:00 é o mesmo instante que 12:00 UTC.
      expect(evento.start.toUtc(), DateTime.utc(2026, 8, 1, 12, 0));
      expect(evento.end.toUtc(), DateTime.utc(2026, 8, 1, 13, 0));
    });
  });

  group('GoogleCalendarEvent.fromApiJson — evento em UTC', () {
    test('evento mandado com "Z" (UTC) é interpretado corretamente', () {
      final json = _googleEventJson(
        start: {'dateTime': '2026-08-01T12:00:00Z'},
        end: {'dateTime': '2026-08-01T13:00:00Z'},
      );

      final evento = GoogleCalendarEvent.fromApiJson(json);

      expect(evento.start.toUtc(), DateTime.utc(2026, 8, 1, 12, 0));
      expect(evento.start.isUtc, true);
    });
  });

  group('GoogleCalendarEvent.fromApiJson — evento de dia inteiro', () {
    test('REGRESSÃO: data pura não deve deslocar de dia (era interpretada como meia-noite local)', () {
      final json = _googleEventJson(
        start: {'date': '2026-08-01'},
        end: {'date': '2026-08-02'}, // Google manda o dia seguinte como fim exclusivo
      );

      final evento = GoogleCalendarEvent.fromApiJson(json);

      expect(evento.allDay, true);
      expect(evento.start, DateTime.utc(2026, 8, 1));
      expect(evento.end, DateTime.utc(2026, 8, 2));
      expect(evento.start.isUtc, true);
    });
  });

  group('GoogleCalendarEvent.fromApiJson — status', () {
    test('evento cancelado no Google chega com status "cancelled"', () {
      final json = _googleEventJson(
        start: {'dateTime': '2026-08-01T09:00:00Z'},
        end: {'dateTime': '2026-08-01T10:00:00Z'},
        status: 'cancelled',
      );

      final evento = GoogleCalendarEvent.fromApiJson(json);

      expect(evento.status, 'cancelled');
    });
  });

  group('GoogleCalendarMapper.toGoogleApiJson — Bússola → Google', () {
    test('evento com hora manda dateTime em UTC + o fuso do evento', () {
      final local = _buildLocalEvent(
        start: DateTime.utc(2026, 8, 1, 12, 0),
        end: DateTime.utc(2026, 8, 1, 13, 0),
      );

      final json = GoogleCalendarMapper.toGoogleApiJson(local);

      expect(json['start']['dateTime'], '2026-08-01T12:00:00.000Z');
      expect(json['start']['timeZone'], 'America/Sao_Paulo');
      expect(json['end']['dateTime'], '2026-08-01T13:00:00.000Z');
    });

    test('evento de dia inteiro manda "date" (sem hora), não "dateTime"', () {
      final local = _buildLocalEvent(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 1, 23, 59),
        allDay: true,
      );

      final json = GoogleCalendarMapper.toGoogleApiJson(local);

      expect(json['start'].containsKey('date'), true);
      expect(json['start'].containsKey('dateTime'), false);
      expect(json['start']['date'], '2026-08-01');
    });

    test('inclui local/descrição só quando existirem', () {
      final semLocalNemDescricao = _buildLocalEvent(
        start: DateTime.utc(2026, 8, 1, 9),
        end: DateTime.utc(2026, 8, 1, 10),
      );

      final json = GoogleCalendarMapper.toGoogleApiJson(semLocalNemDescricao);

      expect(json.containsKey('location'), false);
      expect(json.containsKey('description'), false);
    });
  });

  group('GoogleCalendarMapper.toRemoteCalendarEvent — Google → genérico', () {
    test('converte os campos do Google 1:1 para o tipo genérico', () {
      final googleEvent = GoogleCalendarEvent.fromApiJson(_googleEventJson(
        start: {'dateTime': '2026-08-01T09:00:00-03:00'},
        end: {'dateTime': '2026-08-01T10:00:00-03:00'},
        location: 'Sala 2',
      ));

      final remoto = GoogleCalendarMapper.toRemoteCalendarEvent(googleEvent);

      expect(remoto.externalId, 'google-evt-1');
      expect(remoto.location, 'Sala 2');
      expect(remoto.start, googleEvent.start);
      expect(remoto.status, googleEvent.status);
    });
  });

  group('RemoteCalendarEvent.toEventModel — genérico → Bússola (via Google nesta etapa)', () {
    test('constrói um EventModel novo, com googleEventId e syncOrigin=google', () {
      final googleEvent = GoogleCalendarEvent.fromApiJson(_googleEventJson(
        start: {'dateTime': '2026-08-01T09:00:00-03:00'},
        end: {'dateTime': '2026-08-01T10:00:00-03:00'},
      ));
      final remoto = GoogleCalendarMapper.toRemoteCalendarEvent(googleEvent);

      final model = remoto.toEventModel(userId: 'user-1', calendarId: 'cal-1', provider: CalendarProvider.googleCalendar);

      expect(model.googleEventId, 'google-evt-1');
      expect(model.syncOrigin, SyncOrigin.google);
      expect(model.userId, 'user-1');
      expect(model.calendarId, 'cal-1');
    });

    test('REGRESSÃO: lastSyncedAt e updatedAt usam o mesmo instante (nunca updatedAt > lastSyncedAt)', () {
      final googleEvent = GoogleCalendarEvent.fromApiJson(_googleEventJson(
        start: {'dateTime': '2026-08-01T09:00:00Z'},
        end: {'dateTime': '2026-08-01T10:00:00Z'},
      ));
      final remoto = GoogleCalendarMapper.toRemoteCalendarEvent(googleEvent);

      final model = remoto.toEventModel(userId: 'user-1', calendarId: 'cal-1', provider: CalendarProvider.googleCalendar);

      expect(model.updatedAt.isAfter(model.lastSyncedAt!), false);
      expect(model.updatedAt, model.lastSyncedAt);
    });

    test('preserva categoria/prioridade do evento local existente ao atualizar', () {
      final existente = _buildLocalEvent(start: DateTime.utc(2026, 8, 1, 9), end: DateTime.utc(2026, 8, 1, 10))
          .copyWith(priority: Priority.alta, categoryId: 'cat-1');

      final googleEvent = GoogleCalendarEvent.fromApiJson(_googleEventJson(
        start: {'dateTime': '2026-08-01T09:00:00Z'},
        end: {'dateTime': '2026-08-01T10:00:00Z'},
      ));
      final remoto = GoogleCalendarMapper.toRemoteCalendarEvent(googleEvent);

      final atualizado = remoto.toEventModel(
        userId: 'user-1',
        calendarId: 'cal-1',
        provider: CalendarProvider.googleCalendar,
        existingLocal: existente,
      );

      expect(atualizado.id, existente.id);
      expect(atualizado.priority, Priority.alta);
      expect(atualizado.categoryId, 'cat-1');
    });
  });
}

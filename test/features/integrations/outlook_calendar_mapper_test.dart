import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/data/mappers/outlook_calendar_mapper.dart';

Map<String, dynamic> _outlookEventJson({
  required Map<String, dynamic> start,
  required Map<String, dynamic> end,
  bool isAllDay = false,
  bool isCancelled = false,
  String? location,
  String? bodyContent,
  Map<String, dynamic>? recurrence,
}) {
  return {
    'id': 'outlook-evt-1',
    'subject': 'Reunião de teste',
    if (bodyContent != null) 'body': {'contentType': 'text', 'content': bodyContent},
    if (location != null) 'location': {'displayName': location},
    'start': start,
    'end': end,
    'isAllDay': isAllDay,
    'isCancelled': isCancelled,
    'lastModifiedDateTime': '2026-08-01T10:00:00.0000000Z',
    if (recurrence != null) 'recurrence': recurrence,
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
  group('OutlookCalendarEvent.fromApiJson — leitura sempre em UTC', () {
    test('evento normal: dateTime+timeZone=UTC (padrão do Graph) é interpretado como instante UTC', () {
      final json = _outlookEventJson(
        start: {'dateTime': '2026-08-01T12:00:00.0000000', 'timeZone': 'UTC'},
        end: {'dateTime': '2026-08-01T13:00:00.0000000', 'timeZone': 'UTC'},
        location: 'Sala 2',
        bodyContent: 'Pauta X',
      );

      final evento = OutlookCalendarEvent.fromApiJson(json);

      expect(evento.allDay, false);
      expect(evento.location, 'Sala 2');
      expect(evento.description, 'Pauta X');
      expect(evento.start, DateTime.utc(2026, 8, 1, 12, 0));
      expect(evento.end, DateTime.utc(2026, 8, 1, 13, 0));
      expect(evento.start.isUtc, true);
    });

    test('REGRESSÃO — evento de dia inteiro: mesmo vindo como dateTime+UTC (não "date" como o Google), não desloca de dia', () {
      final json = _outlookEventJson(
        start: {'dateTime': '2026-08-01T00:00:00.0000000', 'timeZone': 'UTC'},
        end: {'dateTime': '2026-08-02T00:00:00.0000000', 'timeZone': 'UTC'}, // fim exclusivo
        isAllDay: true,
      );

      final evento = OutlookCalendarEvent.fromApiJson(json);

      expect(evento.allDay, true);
      expect(evento.start, DateTime.utc(2026, 8, 1));
      expect(evento.end, DateTime.utc(2026, 8, 2));
    });

    test('evento cancelado: isCancelled=true', () {
      final json = _outlookEventJson(
        start: {'dateTime': '2026-08-01T09:00:00.0000000', 'timeZone': 'UTC'},
        end: {'dateTime': '2026-08-01T10:00:00.0000000', 'timeZone': 'UTC'},
        isCancelled: true,
      );

      final evento = OutlookCalendarEvent.fromApiJson(json);

      expect(evento.cancelled, true);
    });

    test('sem body/location: description e location ficam null, sem quebrar', () {
      final json = _outlookEventJson(
        start: {'dateTime': '2026-08-01T09:00:00.0000000', 'timeZone': 'UTC'},
        end: {'dateTime': '2026-08-01T10:00:00.0000000', 'timeZone': 'UTC'},
      );

      final evento = OutlookCalendarEvent.fromApiJson(json);

      expect(evento.description, isNull);
      expect(evento.location, isNull);
    });
  });

  group('OutlookCalendarMapper.toGraphApiJson — Bússola → Outlook', () {
    test('evento com hora: manda dateTime em UTC + o fuso IANA do evento (Graph aceita IANA direto)', () {
      final local = _buildLocalEvent(start: DateTime.utc(2026, 8, 1, 12, 0), end: DateTime.utc(2026, 8, 1, 13, 0));

      final json = OutlookCalendarMapper.toGraphApiJson(local);

      expect(json['start']['dateTime'], '2026-08-01T12:00:00.000Z');
      expect(json['start']['timeZone'], 'America/Sao_Paulo');
      expect(json['isAllDay'], false);
    });

    test('evento de dia inteiro: manda timeZone=UTC e o fim é o dia SEGUINTE (convenção exclusiva)', () {
      final local = _buildLocalEvent(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 1, 23, 59), allDay: true);

      final json = OutlookCalendarMapper.toGraphApiJson(local);

      expect(json['isAllDay'], true);
      expect(json['start']['timeZone'], 'UTC');
      expect(json['start']['dateTime'], '2026-08-01T00:00:00.000Z');
      expect(json['end']['dateTime'], '2026-08-02T00:00:00.000Z');
    });

    test('inclui body/location só quando existirem', () {
      final semNada = _buildLocalEvent(start: DateTime.utc(2026, 8, 1, 9), end: DateTime.utc(2026, 8, 1, 10));

      final json = OutlookCalendarMapper.toGraphApiJson(semNada);

      expect(json.containsKey('body'), false);
      expect(json.containsKey('location'), false);
    });
  });

  group('OutlookCalendarMapper.toRemoteCalendarEvent — Outlook → genérico', () {
    test('converte 1:1, status derivado de isCancelled', () {
      final outlookEvent = OutlookCalendarEvent.fromApiJson(_outlookEventJson(
        start: {'dateTime': '2026-08-01T09:00:00.0000000', 'timeZone': 'UTC'},
        end: {'dateTime': '2026-08-01T10:00:00.0000000', 'timeZone': 'UTC'},
        isCancelled: true,
      ));

      final remoto = OutlookCalendarMapper.toRemoteCalendarEvent(outlookEvent);

      expect(remoto.externalId, 'outlook-evt-1');
      expect(remoto.isCancelled, true);
      expect(remoto.start, outlookEvent.start);
    });
  });

  group('OutlookCalendarMapper.mapRecurrence — sem perda', () {
    test('diário simples (interval=1)', () {
      final resultado = OutlookCalendarMapper.mapRecurrence({
        'pattern': {'type': 'daily', 'interval': 1},
        'range': {'type': 'noEnd'},
      });

      expect(resultado.type, RecurrenceType.diario);
      expect(resultado.perdaDeInformacao, false);
    });

    test('semanal simples (interval=1, sem múltiplos dias)', () {
      final resultado = OutlookCalendarMapper.mapRecurrence({
        'pattern': {'type': 'weekly', 'interval': 1, 'daysOfWeek': ['monday']},
        'range': {'type': 'noEnd'},
      });

      expect(resultado.type, RecurrenceType.semanal);
      expect(resultado.perdaDeInformacao, false);
    });

    test('quinzenal (weekly, interval=2)', () {
      final resultado = OutlookCalendarMapper.mapRecurrence({
        'pattern': {'type': 'weekly', 'interval': 2},
        'range': {'type': 'noEnd'},
      });

      expect(resultado.type, RecurrenceType.quinzenal);
      expect(resultado.perdaDeInformacao, false);
    });

    test('mensal simples (absoluteMonthly, interval=1) — sem perda', () {
      final resultado = OutlookCalendarMapper.mapRecurrence({
        'pattern': {'type': 'absoluteMonthly', 'interval': 1, 'dayOfMonth': 5},
        'range': {'type': 'endDate', 'endDate': '2027-01-01'},
      });

      expect(resultado.type, RecurrenceType.mensal);
      expect(resultado.perdaDeInformacao, false);
      expect(resultado.until, DateTime.parse('2027-01-01'));
    });

    test('anual simples (absoluteYearly) — sem perda', () {
      final resultado = OutlookCalendarMapper.mapRecurrence({
        'pattern': {'type': 'absoluteYearly', 'interval': 1},
        'range': {'type': 'numbered', 'numberOfOccurrences': 5},
      });

      expect(resultado.type, RecurrenceType.anual);
      expect(resultado.perdaDeInformacao, false);
      expect(resultado.count, 5);
    });

    test('nenhuma recorrência (json null) → nunca', () {
      final resultado = OutlookCalendarMapper.mapRecurrence(null);

      expect(resultado.type, RecurrenceType.nunca);
      expect(resultado.perdaDeInformacao, false);
    });
  });

  group('OutlookCalendarMapper.mapRecurrence — COM perda de informação (documentada, não inventada)', () {
    test('mensal com intervalo != 1: mapeado como mensal, mas com perda marcada', () {
      final resultado = OutlookCalendarMapper.mapRecurrence({
        'pattern': {'type': 'absoluteMonthly', 'interval': 3},
        'range': {'type': 'noEnd'},
      });

      expect(resultado.type, RecurrenceType.mensal);
      expect(resultado.perdaDeInformacao, true);
      expect(resultado.motivoDaPerda, isNotNull);
    });

    test('relativeMonthly ("toda 2ª terça-feira do mês"): mapeado como mensal, com perda marcada', () {
      final resultado = OutlookCalendarMapper.mapRecurrence({
        'pattern': {'type': 'relativeMonthly', 'interval': 1, 'daysOfWeek': ['tuesday'], 'index': 'second'},
        'range': {'type': 'noEnd'},
      });

      expect(resultado.type, RecurrenceType.mensal);
      expect(resultado.perdaDeInformacao, true);
    });

    test('semanal com múltiplos dias da semana: mapeado como personalizado, com perda marcada', () {
      final resultado = OutlookCalendarMapper.mapRecurrence({
        'pattern': {'type': 'weekly', 'interval': 1, 'daysOfWeek': ['monday', 'wednesday', 'friday']},
        'range': {'type': 'noEnd'},
      });

      expect(resultado.type, RecurrenceType.personalizado);
      expect(resultado.perdaDeInformacao, true);
      expect(resultado.motivoDaPerda, contains('dia(s) da semana'));
    });

    test('padrão desconhecido/não suportado: mapeado como personalizado, com perda marcada, sem inventar semântica', () {
      final resultado = OutlookCalendarMapper.mapRecurrence({
        'pattern': {'type': 'algumTipoNovoQueAMicrosoftAdicionouNoFuturo', 'interval': 1},
        'range': {'type': 'noEnd'},
      });

      expect(resultado.type, RecurrenceType.personalizado);
      expect(resultado.perdaDeInformacao, true);
      expect(resultado.motivoDaPerda, contains('desconhecido'));
    });
  });
}

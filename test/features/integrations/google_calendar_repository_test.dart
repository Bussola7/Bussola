import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/data/datasources/google_calendar_datasource.dart';
import 'package:bussola/features/integrations/data/repositories/google_calendar_repository.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';

/// Data Source falso: simula o erro específico do Google
/// (`GoogleTokenExpiredException`) em qualquer um dos 4 métodos, sem
/// nenhuma chamada HTTP real.
class _FakeGoogleCalendarDataSource extends GoogleCalendarDataSource {
  bool lancarErroExpirado;

  _FakeGoogleCalendarDataSource({this.lancarErroExpirado = true});

  @override
  Future<({List<GoogleCalendarEvent> events, String? nextSyncToken})> listChangedEvents({
    required String accessToken,
    String? syncToken,
  }) async {
    if (lancarErroExpirado) throw GoogleTokenExpiredException();
    return (events: <GoogleCalendarEvent>[], nextSyncToken: null);
  }

  @override
  Future<GoogleCalendarEvent> createEvent({required String accessToken, required Map<String, dynamic> eventJson}) async {
    if (lancarErroExpirado) throw GoogleTokenExpiredException();
    throw UnimplementedError();
  }

  @override
  Future<GoogleCalendarEvent> updateEvent({
    required String accessToken,
    required String googleEventId,
    required Map<String, dynamic> eventJson,
  }) async {
    if (lancarErroExpirado) throw GoogleTokenExpiredException();
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEvent({required String accessToken, required String googleEventId}) async {
    if (lancarErroExpirado) throw GoogleTokenExpiredException();
  }
}

EventModel _buildEvent({String? googleEventId}) {
  final now = DateTime.now();
  return EventModel(
    id: 'evt-1',
    calendarId: 'cal-1',
    userId: 'user-1',
    title: 'Evento',
    startDatetime: now,
    endDatetime: now.add(const Duration(hours: 1)),
    timezone: 'America/Sao_Paulo',
    allDay: false,
    googleEventId: googleEventId,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('GoogleCalendarRepository — conversão de erro na fronteira (Etapa 1.1)', () {
    test('listChangedEvents: GoogleTokenExpiredException vira RemoteCalendarAuthExpiredException', () async {
      final repo = GoogleCalendarRepository(dataSource: _FakeGoogleCalendarDataSource());

      await expectLater(
        repo.listChangedEvents(accessToken: 'token-qualquer'),
        throwsA(isA<RemoteCalendarAuthExpiredException>()),
      );
    });

    test('createEvent: GoogleTokenExpiredException vira RemoteCalendarAuthExpiredException', () async {
      final repo = GoogleCalendarRepository(dataSource: _FakeGoogleCalendarDataSource());

      await expectLater(
        repo.createEvent(accessToken: 'token-qualquer', event: _buildEvent()),
        throwsA(isA<RemoteCalendarAuthExpiredException>()),
      );
    });

    test('updateEvent: GoogleTokenExpiredException vira RemoteCalendarAuthExpiredException', () async {
      final repo = GoogleCalendarRepository(dataSource: _FakeGoogleCalendarDataSource());

      await expectLater(
        repo.updateEvent(accessToken: 'token-qualquer', event: _buildEvent(googleEventId: 'g-1')),
        throwsA(isA<RemoteCalendarAuthExpiredException>()),
      );
    });

    test('deleteEvent: GoogleTokenExpiredException vira RemoteCalendarAuthExpiredException', () async {
      final repo = GoogleCalendarRepository(dataSource: _FakeGoogleCalendarDataSource());

      await expectLater(
        repo.deleteEvent(accessToken: 'token-qualquer', externalEventId: 'g-1'),
        throwsA(isA<RemoteCalendarAuthExpiredException>()),
      );
    });

    test('REGRA: o erro específico do Google (GoogleTokenExpiredException) nunca escapa do Repository', () async {
      final repo = GoogleCalendarRepository(dataSource: _FakeGoogleCalendarDataSource());

      try {
        await repo.listChangedEvents(accessToken: 'token-qualquer');
        fail('deveria ter lançado uma exceção');
      } catch (e) {
        expect(e, isNot(isA<GoogleTokenExpiredException>()));
        expect(e, isA<RemoteCalendarAuthExpiredException>());
      }
    });

    test('sem erro: listChangedEvents funciona normalmente e devolve o tipo genérico', () async {
      final repo = GoogleCalendarRepository(dataSource: _FakeGoogleCalendarDataSource(lancarErroExpirado: false));

      final resultado = await repo.listChangedEvents(accessToken: 'token-qualquer');

      expect(resultado.events, isEmpty);
    });
  });
}

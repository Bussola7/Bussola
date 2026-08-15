import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/data/datasources/google_calendar_datasource.dart';
import 'package:bussola/features/integrations/data/mappers/google_calendar_mapper.dart';
import 'package:bussola/features/integrations/domain/entities/remote_calendar_event.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/repositories/remote_calendar_repository.dart';

/// Implementação concreta de [RemoteCalendarRepository] para o Google
/// Calendar. Camada fina sobre o [GoogleCalendarDataSource]: aplica o
/// [GoogleCalendarMapper] nos dois sentidos, converte o tipo específico
/// do Google (`GoogleCalendarEvent`) para o tipo genérico
/// ([RemoteCalendarEvent]) na fronteira, e converte o erro específico do
/// Google (`GoogleTokenExpiredException`) para [RemoteCalendarAuthExpiredException]
/// — o `CalendarSyncService` nunca vê nenhum dos dois tipos do Google.
class GoogleCalendarRepository implements RemoteCalendarRepository {
  final GoogleCalendarDataSource _dataSource;

  GoogleCalendarRepository({GoogleCalendarDataSource? dataSource}) : _dataSource = dataSource ?? GoogleCalendarDataSource();

  /// Roda [acao] convertendo `GoogleTokenExpiredException` (erro
  /// específico do Google, lançado pelo Data Source) em
  /// [RemoteCalendarAuthExpiredException] (erro de domínio, genérico) —
  /// é aqui, na fronteira data→domínio, que essa conversão deve
  /// acontecer, nunca dentro do `CalendarSyncService`.
  Future<T> _comConversaoDeErroDeAutenticacao<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on GoogleTokenExpiredException {
      throw const RemoteCalendarAuthExpiredException(
        'O access token do Google Calendar expirou ou é inválido.',
      );
    }
  }

  @override
  Future<({List<RemoteCalendarEvent> events, String? nextSyncToken})> listChangedEvents({
    required String accessToken,
    String? syncToken,
  }) {
    return _comConversaoDeErroDeAutenticacao(() async {
      final resultado = await _dataSource.listChangedEvents(accessToken: accessToken, syncToken: syncToken);
      return (
        events: resultado.events.map(GoogleCalendarMapper.toRemoteCalendarEvent).toList(),
        nextSyncToken: resultado.nextSyncToken,
      );
    });
  }

  @override
  Future<RemoteCalendarEvent> createEvent({required String accessToken, required EventModel event}) {
    return _comConversaoDeErroDeAutenticacao(() async {
      final criado = await _dataSource.createEvent(accessToken: accessToken, eventJson: GoogleCalendarMapper.toGoogleApiJson(event));
      return GoogleCalendarMapper.toRemoteCalendarEvent(criado);
    });
  }

  @override
  Future<RemoteCalendarEvent> updateEvent({required String accessToken, required EventModel event}) {
    return _comConversaoDeErroDeAutenticacao(() async {
      if (event.googleEventId == null) {
        throw ArgumentError('Evento ainda não existe no Google Calendar (googleEventId nulo).');
      }
      final atualizado = await _dataSource.updateEvent(
        accessToken: accessToken,
        googleEventId: event.googleEventId!,
        eventJson: GoogleCalendarMapper.toGoogleApiJson(event),
      );
      return GoogleCalendarMapper.toRemoteCalendarEvent(atualizado);
    });
  }

  @override
  Future<void> deleteEvent({required String accessToken, required String externalEventId}) {
    return _comConversaoDeErroDeAutenticacao(() {
      return _dataSource.deleteEvent(accessToken: accessToken, googleEventId: externalEventId);
    });
  }
}

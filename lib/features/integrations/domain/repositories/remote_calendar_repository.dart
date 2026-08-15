import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/domain/entities/remote_calendar_event.dart';

/// Contrato que qualquer provedor de calendário remoto (Google, Outlook,
/// ...) precisa cumprir para o `CalendarSyncService` conseguir
/// sincronizar com ele. Representa só as operações que a orquestração de
/// fato usa — nada de nomes ou tipos específicos de um provedor.
///
/// O Google já tem a implementação concreta: `GoogleCalendarRepository`
/// (em `data/repositories/google_calendar_repository.dart`) implementa
/// esta interface.
abstract class RemoteCalendarRepository {
  /// Busca os eventos alterados desde a última sincronização
  /// (incremental, via [syncToken]) ou uma janela inicial, se [syncToken]
  /// for nulo. Devolve também o token a ser usado na próxima chamada.
  Future<({List<RemoteCalendarEvent> events, String? nextSyncToken})> listChangedEvents({
    required String accessToken,
    String? syncToken,
  });

  Future<RemoteCalendarEvent> createEvent({required String accessToken, required EventModel event});

  Future<RemoteCalendarEvent> updateEvent({required String accessToken, required EventModel event});

  Future<void> deleteEvent({required String accessToken, required String externalEventId});
}

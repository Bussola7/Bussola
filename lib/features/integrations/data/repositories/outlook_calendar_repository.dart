import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/data/datasources/outlook_calendar_datasource.dart';
import 'package:bussola/features/integrations/data/mappers/outlook_calendar_mapper.dart';
import 'package:bussola/features/integrations/domain/entities/remote_calendar_event.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/repositories/remote_calendar_repository.dart';

/// Implementação concreta de [RemoteCalendarRepository] para o Outlook
/// Calendar (Microsoft Graph). Camada fina sobre o
/// [OutlookCalendarDataSource]: aplica o [OutlookCalendarMapper] nos dois
/// sentidos, e converte o tipo específico do Outlook
/// (`OutlookCalendarEvent`) para o tipo genérico ([RemoteCalendarEvent])
/// na fronteira — o `CalendarSyncService` nunca vê `OutlookCalendarEvent`,
/// só fala com a interface.
///
/// Não contém NENHUMA lógica de orquestração/sincronização — isso é
/// responsabilidade exclusiva do `CalendarSyncService`, que já foi
/// generalizado (Etapas 1.1–1.4) para funcionar com qualquer implementação
/// desta interface, sem precisar saber que o Outlook existe.
///
/// Nota sobre `EventModel.outlookEventId` (corrigido pós-Etapa 1.15): esta
/// classe agora usa o campo dedicado `outlookEventId` — não mais
/// `googleEventId` (bug real que existia antes: usar o ID do Google para
/// encontrar/atualizar o evento no Outlook, quebrando o vínculo do
/// primeiro provedor sempre que o segundo sincronizasse). Os dois campos
/// coexistem em `EventModel`, permitindo o mesmo evento local ficar
/// vinculado a Google e Outlook simultaneamente.
class OutlookCalendarRepository implements RemoteCalendarRepository {
  final OutlookCalendarDataSource _dataSource;

  OutlookCalendarRepository({OutlookCalendarDataSource? dataSource}) : _dataSource = dataSource ?? OutlookCalendarDataSource();

  /// Roda [acao] convertendo `OutlookTokenExpiredException` (erro
  /// específico do Outlook, lançado pelo Data Source) em
  /// [RemoteCalendarAuthExpiredException] (erro de domínio, genérico) —
  /// mesma fronteira usada pelo `GoogleCalendarRepository`.
  Future<T> _comConversaoDeErroDeAutenticacao<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on OutlookTokenExpiredException {
      throw const RemoteCalendarAuthExpiredException(
        'O access token do Outlook Calendar expirou ou é inválido.',
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
        events: resultado.events.map(OutlookCalendarMapper.toRemoteCalendarEvent).toList(),
        nextSyncToken: resultado.nextSyncToken,
      );
    });
  }

  @override
  Future<RemoteCalendarEvent> createEvent({required String accessToken, required EventModel event}) {
    return _comConversaoDeErroDeAutenticacao(() async {
      final criado = await _dataSource.createEvent(accessToken: accessToken, eventJson: OutlookCalendarMapper.toGraphApiJson(event));
      return OutlookCalendarMapper.toRemoteCalendarEvent(criado);
    });
  }

  @override
  Future<RemoteCalendarEvent> updateEvent({required String accessToken, required EventModel event}) {
    return _comConversaoDeErroDeAutenticacao(() async {
      if (event.outlookEventId == null) {
        throw ArgumentError('Evento ainda não existe no Outlook Calendar (outlookEventId nulo).');
      }
      final atualizado = await _dataSource.updateEvent(
        accessToken: accessToken,
        outlookEventId: event.outlookEventId!,
        eventJson: OutlookCalendarMapper.toGraphApiJson(event),
      );
      return OutlookCalendarMapper.toRemoteCalendarEvent(atualizado);
    });
  }

  @override
  Future<void> deleteEvent({required String accessToken, required String externalEventId}) {
    return _comConversaoDeErroDeAutenticacao(() {
      return _dataSource.deleteEvent(accessToken: accessToken, outlookEventId: externalEventId);
    });
  }
}

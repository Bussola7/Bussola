import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bussola/features/integrations/data/mappers/outlook_calendar_mapper.dart';

/// Exceção específica de quando o `access_token` expirou/é inválido — o
/// `OutlookCalendarRepository` sabe capturar este erro e convertê-lo para
/// a exceção de domínio genérica antes de qualquer coisa sair desta camada.
class OutlookTokenExpiredException implements Exception {}

/// Único ponto do sistema que faz chamadas HTTP diretas à Microsoft Graph
/// Calendar API. Nenhuma outra camada (Service, UseCase, tela) deve
/// montar essas URLs ou headers na mão.
///
/// Sincronização incremental: usa o mecanismo oficial de "delta query" do
/// Graph (`/me/events/delta`) — equivalente ao `syncToken` do Google, só
/// que aqui o "token" é uma URL COMPLETA (`@odata.deltaLink`), não um
/// valor opaco curto. Isso não muda nada na coluna `integrations.sync_token`
/// (ela já é texto livre) — só guardamos essa URL inteira lá.
///
/// IMPORTANTE (transparência): este código foi escrito seguindo a
/// documentação pública da Microsoft Graph API v1.0, mas **não foi
/// testado contra a API real neste ambiente** — não há acesso de rede à
/// Microsoft nem credenciais OAuth configuradas aqui.
class OutlookCalendarDataSource {
  static const _baseUrl = 'https://graph.microsoft.com/v1.0';

  final http.Client? _clientOverride;

  /// Preguiçoso pelo mesmo motivo do `GoogleCalendarDataSource`.
  http.Client get _client => _clientOverride ?? http.Client();

  OutlookCalendarDataSource({http.Client? client}) : _clientOverride = client;

  Map<String, String> _headers(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  void _throwIfExpired(http.Response response) {
    if (response.statusCode == 401) throw OutlookTokenExpiredException();
  }

  /// Busca eventos alterados desde a última sincronização.
  ///
  /// Se [syncToken] for informado, chama essa URL diretamente (ela já
  /// contém todos os parâmetros necessários — é assim que a delta query
  /// do Graph funciona, diferente do `syncToken` do Google). Caso
  /// contrário, é a primeira sincronização: chama `/me/events/delta` sem
  /// nenhum parâmetro, que devolve TODOS os eventos (o Graph não aceita
  /// uma janela de datas customizada no delta de `/me/events`, diferente
  /// do Google — isso é uma limitação real da API, não uma escolha nossa).
  ///
  /// PAGINAÇÃO (Etapa 1.8): o Graph pode devolver a resposta em várias
  /// páginas — cada página com `@odata.nextLink` significa "ainda tem
  /// mais", e só a ÚLTIMA página traz `@odata.deltaLink` (o valor a
  /// guardar para a PRÓXIMA sincronização incremental). Este método segue
  /// `nextLink` em loop, acumulando os eventos de todas as páginas, e só
  /// devolve o `deltaLink` capturado na página final — nunca um
  /// `nextLink` no lugar do `deltaLink` (guardar um `nextLink` como se
  /// fosse `deltaLink` faria a próxima sincronização recomeçar do meio,
  /// perdendo eventos anteriores a esse ponto).
  ///
  /// Se uma página no MEIO da paginação falhar (erro de rede, 401, HTTP
  /// != 200), a exceção sobe imediatamente — nenhum resultado parcial é
  /// devolvido como se fosse completo; a sincronização inteira falha e
  /// pode ser repetida do zero com segurança (nada foi salvo ainda nesta
  /// camada).
  Future<({List<OutlookCalendarEvent> events, String? nextSyncToken})> listChangedEvents({
    required String accessToken,
    String? syncToken,
  }) async {
    final eventosAcumulados = <OutlookCalendarEvent>[];
    var uri = syncToken != null ? Uri.parse(syncToken) : Uri.parse('$_baseUrl/me/events/delta');

    while (true) {
      final response = await _client.get(uri, headers: _headers(accessToken));
      _throwIfExpired(response);

      if (response.statusCode == 410) {
        // deltaLink expirado/inválido (Graph devolve 410 Gone, geralmente
        // com um código de erro "SyncStateNotFound") — a API exige
        // recomeçar sem ele (full sync), mesmo tratamento do 410 do Google.
        // Descarta qualquer página já acumulada nesta chamada — o full
        // sync começa do zero, de propósito.
        return listChangedEvents(accessToken: accessToken, syncToken: null);
      }
      if (response.statusCode != 200) {
        throw Exception('Falha ao buscar eventos do Outlook Calendar (HTTP ${response.statusCode}).');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (body['value'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      eventosAcumulados.addAll(items.map(OutlookCalendarEvent.fromApiJson));

      final nextLink = body['@odata.nextLink'] as String?;
      if (nextLink != null) {
        uri = Uri.parse(nextLink);
        continue; // ainda tem página — não é a última
      }

      // Página final: só aqui pegamos o deltaLink (pode ser nulo em
      // respostas atípicas — quem chama trata isso como "sem token para
      // a próxima incremental", igual ao Google quando `nextSyncToken`
      // vem nulo).
      final deltaLink = body['@odata.deltaLink'] as String?;
      return (events: eventosAcumulados, nextSyncToken: deltaLink);
    }
  }

  Future<OutlookCalendarEvent> createEvent({required String accessToken, required Map<String, dynamic> eventJson}) async {
    final uri = Uri.parse('$_baseUrl/me/events');
    final response = await _client.post(uri, headers: _headers(accessToken), body: jsonEncode(eventJson));
    _throwIfExpired(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Falha ao criar evento no Outlook Calendar (HTTP ${response.statusCode}).');
    }
    return OutlookCalendarEvent.fromApiJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<OutlookCalendarEvent> updateEvent({
    required String accessToken,
    required String outlookEventId,
    required Map<String, dynamic> eventJson,
  }) async {
    final uri = Uri.parse('$_baseUrl/me/events/$outlookEventId');
    final response = await _client.patch(uri, headers: _headers(accessToken), body: jsonEncode(eventJson));
    _throwIfExpired(response);
    if (response.statusCode != 200) {
      throw Exception('Falha ao atualizar evento no Outlook Calendar (HTTP ${response.statusCode}).');
    }
    return OutlookCalendarEvent.fromApiJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteEvent({required String accessToken, required String outlookEventId}) async {
    final uri = Uri.parse('$_baseUrl/me/events/$outlookEventId');
    final response = await _client.delete(uri, headers: _headers(accessToken));
    _throwIfExpired(response);
    // 404 = já estava excluído do lado do Outlook — não é um erro real aqui.
    if (response.statusCode != 200 && response.statusCode != 204 && response.statusCode != 404) {
      throw Exception('Falha ao excluir evento no Outlook Calendar (HTTP ${response.statusCode}).');
    }
  }
}

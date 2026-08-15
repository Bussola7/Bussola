import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bussola/features/integrations/data/mappers/google_calendar_mapper.dart';

/// Exceção específica de quando o `access_token` expirou/é inválido — o
/// `GoogleAuthService` sabe capturar este erro e tentar renovar o token
/// antes de repetir a chamada.
class GoogleTokenExpiredException implements Exception {}

/// Único ponto do sistema que faz chamadas HTTP diretas à Google Calendar
/// API. Nenhuma outra camada (Service, UseCase, tela) deve montar essas
/// URLs ou headers na mão.
///
/// IMPORTANTE (transparência): este código foi escrito seguindo a
/// documentação pública da Google Calendar API v3, mas **não foi testado
/// contra a API real neste ambiente** — não há acesso de rede ao Google
/// nem credenciais OAuth configuradas aqui. Validar contra a API real é
/// um passo pendente para quando este projeto rodar num ambiente com
/// Client ID/Secret configurados de verdade.
class GoogleCalendarDataSource {
  static const _baseUrl = 'https://www.googleapis.com/calendar/v3';

  final http.Client? _clientOverride;

  /// Preguiçoso pelo mesmo motivo do `GoogleAuthService`: um `http.Client()`
  /// real de verdade é barato de construir, mas manter o padrão consistente
  /// em todo o projeto facilita revisar e testar sem exceções especiais.
  http.Client get _client => _clientOverride ?? http.Client();

  GoogleCalendarDataSource({http.Client? client}) : _clientOverride = client;

  Map<String, String> _headers(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  void _throwIfExpired(http.Response response) {
    if (response.statusCode == 401) throw GoogleTokenExpiredException();
  }

  /// Busca eventos alterados desde a última sincronização. Se [syncToken]
  /// for informado, usa o mecanismo oficial de sincronização incremental
  /// da Google (só volta o que mudou); caso contrário, é a primeira sincronização
  /// e busca uma janela inicial (últimos 30 dias + próximos 180 dias).
  ///
  /// Devolve tanto os eventos quanto o `nextSyncToken` — que deve ser
  /// guardado (`integrations.sync_token`) para a próxima chamada.
  Future<({List<GoogleCalendarEvent> events, String? nextSyncToken})> listChangedEvents({
    required String accessToken,
    String? syncToken,
  }) async {
    final params = <String, String>{'singleEvents': 'true'};
    if (syncToken != null) {
      params['syncToken'] = syncToken;
    } else {
      final agora = DateTime.now().toUtc();
      params['timeMin'] = agora.subtract(const Duration(days: 30)).toIso8601String();
      params['timeMax'] = agora.add(const Duration(days: 180)).toIso8601String();
    }

    final uri = Uri.parse('$_baseUrl/calendars/primary/events').replace(queryParameters: params);
    final response = await _client.get(uri, headers: _headers(accessToken));
    _throwIfExpired(response);

    if (response.statusCode == 410) {
      // syncToken expirado/inválido — a API exige recomeçar sem ele (full sync).
      return listChangedEvents(accessToken: accessToken, syncToken: null);
    }
    if (response.statusCode != 200) {
      throw Exception('Falha ao buscar eventos do Google Calendar (HTTP ${response.statusCode}).');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return (
      events: items.map(GoogleCalendarEvent.fromApiJson).toList(),
      nextSyncToken: body['nextSyncToken'] as String?,
    );
  }

  Future<GoogleCalendarEvent> createEvent({required String accessToken, required Map<String, dynamic> eventJson}) async {
    final uri = Uri.parse('$_baseUrl/calendars/primary/events');
    final response = await _client.post(uri, headers: _headers(accessToken), body: jsonEncode(eventJson));
    _throwIfExpired(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Falha ao criar evento no Google Calendar (HTTP ${response.statusCode}).');
    }
    return GoogleCalendarEvent.fromApiJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<GoogleCalendarEvent> updateEvent({
    required String accessToken,
    required String googleEventId,
    required Map<String, dynamic> eventJson,
  }) async {
    final uri = Uri.parse('$_baseUrl/calendars/primary/events/$googleEventId');
    final response = await _client.put(uri, headers: _headers(accessToken), body: jsonEncode(eventJson));
    _throwIfExpired(response);
    if (response.statusCode != 200) {
      throw Exception('Falha ao atualizar evento no Google Calendar (HTTP ${response.statusCode}).');
    }
    return GoogleCalendarEvent.fromApiJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteEvent({required String accessToken, required String googleEventId}) async {
    final uri = Uri.parse('$_baseUrl/calendars/primary/events/$googleEventId');
    final response = await _client.delete(uri, headers: _headers(accessToken));
    _throwIfExpired(response);
    // 410 = já estava excluído do lado do Google — não é um erro real aqui.
    if (response.statusCode != 200 && response.statusCode != 204 && response.statusCode != 410) {
      throw Exception('Falha ao excluir evento no Google Calendar (HTTP ${response.statusCode}).');
    }
  }
}

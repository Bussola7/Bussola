import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:bussola/features/integrations/data/datasources/outlook_calendar_datasource.dart';

/// Cliente HTTP falso: devolve uma resposta configurada por chamada, na
/// ordem — permite simular múltiplas páginas do Graph (cada uma com seu
/// `@odata.nextLink`/`@odata.deltaLink`) sem nenhuma rede real. Estender
/// `http.BaseClient` e sobrescrever `send` é o jeito padrão do pacote
/// `http` de fazer isso — `get()`/`post()`/etc. já delegam para `send()`.
class _FakeHttpClient extends http.BaseClient {
  final List<({int status, Map<String, dynamic> body})> respostas;
  int chamadas = 0;
  final List<String> urlsChamadas = [];

  _FakeHttpClient(this.respostas);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    urlsChamadas.add(request.url.toString());
    final indice = chamadas.clamp(0, respostas.length - 1);
    final resposta = respostas[indice];
    chamadas++;
    final bytes = utf8.encode(jsonEncode(resposta.body));
    return http.StreamedResponse(Stream.value(bytes), resposta.status);
  }
}

Map<String, dynamic> _eventoJson(String id) {
  return {
    'id': id,
    'subject': 'Evento $id',
    'start': {'dateTime': '2026-08-01T09:00:00.0000000', 'timeZone': 'UTC'},
    'end': {'dateTime': '2026-08-01T10:00:00.0000000', 'timeZone': 'UTC'},
    'isAllDay': false,
    'isCancelled': false,
    'lastModifiedDateTime': '2026-08-01T08:00:00.0000000Z',
  };
}

void main() {
  group('OutlookCalendarDataSource.listChangedEvents — paginação (Etapa 1.8)', () {
    test('1 página: deltaLink vem direto, sem seguir nenhum nextLink', () async {
      final fakeClient = _FakeHttpClient([
        (
          status: 200,
          body: {
            'value': [_eventoJson('p1-e1'), _eventoJson('p1-e2')],
            '@odata.deltaLink': 'https://graph.microsoft.com/v1.0/me/events/delta?\$deltatoken=final',
          },
        ),
      ]);
      final dataSource = OutlookCalendarDataSource(client: fakeClient);

      final resultado = await dataSource.listChangedEvents(accessToken: 'token-1');

      expect(resultado.events.length, 2);
      expect(resultado.nextSyncToken, 'https://graph.microsoft.com/v1.0/me/events/delta?\$deltatoken=final');
      expect(fakeClient.chamadas, 1);
    });

    test('múltiplas páginas (nextLink → nextLink → deltaLink): acumula todos os eventos, sem perder nenhum', () async {
      final fakeClient = _FakeHttpClient([
        (
          status: 200,
          body: {
            'value': [_eventoJson('p1-e1')],
            '@odata.nextLink': 'https://graph.microsoft.com/v1.0/me/events/delta?\$skip=1',
          },
        ),
        (
          status: 200,
          body: {
            'value': [_eventoJson('p2-e1')],
            '@odata.nextLink': 'https://graph.microsoft.com/v1.0/me/events/delta?\$skip=2',
          },
        ),
        (
          status: 200,
          body: {
            'value': [_eventoJson('p3-e1')],
            '@odata.deltaLink': 'https://graph.microsoft.com/v1.0/me/events/delta?\$deltatoken=final',
          },
        ),
      ]);
      final dataSource = OutlookCalendarDataSource(client: fakeClient);

      final resultado = await dataSource.listChangedEvents(accessToken: 'token-1');

      // Nenhum evento perdido entre páginas — os 3, de todas as páginas.
      expect(resultado.events.map((e) => e.outlookId).toList(), ['p1-e1', 'p2-e1', 'p3-e1']);
      // O deltaLink salvo é o da ÚLTIMA página, nunca um nextLink intermediário.
      expect(resultado.nextSyncToken, 'https://graph.microsoft.com/v1.0/me/events/delta?\$deltatoken=final');
      expect(fakeClient.chamadas, 3);
      // Confirma que seguiu de fato os nextLink recebidos, na ordem certa.
      expect(fakeClient.urlsChamadas[1], 'https://graph.microsoft.com/v1.0/me/events/delta?\$skip=1');
      expect(fakeClient.urlsChamadas[2], 'https://graph.microsoft.com/v1.0/me/events/delta?\$skip=2');
    });

    test('ausência de deltaLink na página final: nextSyncToken vem nulo (próxima sync será full)', () async {
      final fakeClient = _FakeHttpClient([
        (status: 200, body: {'value': [_eventoJson('p1-e1')]}),
      ]);
      final dataSource = OutlookCalendarDataSource(client: fakeClient);

      final resultado = await dataSource.listChangedEvents(accessToken: 'token-1');

      expect(resultado.events.length, 1);
      expect(resultado.nextSyncToken, isNull);
    });

    test('erro numa página intermediária: a exceção sobe, nenhum resultado parcial é devolvido como completo', () async {
      final fakeClient = _FakeHttpClient([
        (
          status: 200,
          body: {
            'value': [_eventoJson('p1-e1')],
            '@odata.nextLink': 'https://graph.microsoft.com/v1.0/me/events/delta?\$skip=1',
          },
        ),
        (status: 500, body: {'error': 'falha simulada na 2ª página'}),
      ]);
      final dataSource = OutlookCalendarDataSource(client: fakeClient);

      await expectLater(
        dataSource.listChangedEvents(accessToken: 'token-1'),
        throwsException,
      );
      expect(fakeClient.chamadas, 2); // tentou a 2ª página antes de falhar
    });

    test('primeira sincronização (sem syncToken): chama /me/events/delta sem parâmetros', () async {
      final fakeClient = _FakeHttpClient([
        (status: 200, body: {'value': <Map<String, dynamic>>[], '@odata.deltaLink': 'https://exemplo/delta?token=1'}),
      ]);
      final dataSource = OutlookCalendarDataSource(client: fakeClient);

      await dataSource.listChangedEvents(accessToken: 'token-1');

      expect(fakeClient.urlsChamadas.first, 'https://graph.microsoft.com/v1.0/me/events/delta');
    });
  });
}

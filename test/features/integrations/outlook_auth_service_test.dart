import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bussola/core/services/edge_function_caller.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/data/repositories/integration_repository.dart';
import 'package:bussola/features/integrations/domain/services/outlook_auth_service.dart';

/// Repositório falso: guarda o que `disconnect`/`getIntegration` recebem,
/// sem tocar no Supabase.
class _FakeIntegrationRepository extends IntegrationRepository {
  CalendarIntegrationModel? integracao;
  bool desconectarChamado = false;
  CalendarProvider? providerRecebido;

  _FakeIntegrationRepository([this.integracao]);

  @override
  Future<CalendarIntegrationModel?> getIntegration({required String userId, required CalendarProvider provider}) async {
    providerRecebido = provider;
    return integracao;
  }

  @override
  Future<void> disconnect({required String userId, required CalendarProvider provider}) async {
    desconectarChamado = true;
    providerRecebido = provider;
  }
}

/// Fake genérico da abstração de Edge Function — nenhuma chamada real ao
/// Supabase. Registra o nome da função chamada (ou `null` se nenhuma foi).
class _FakeEdgeFunctionCaller implements EdgeFunctionCaller {
  final int statusConfigurado;
  final dynamic dataConfigurada;
  String? nomeChamado;
  int chamadas = 0;

  _FakeEdgeFunctionCaller({this.statusConfigurado = 200, this.dataConfigurada});

  @override
  Future<EdgeFunctionResult> invoke(String functionName, {Map<String, dynamic>? body}) async {
    chamadas++;
    nomeChamado = functionName;
    return EdgeFunctionResult(status: statusConfigurado, data: dataConfigurada);
  }
}

CalendarIntegrationModel _buildIntegration({required IntegrationStatus status}) {
  return CalendarIntegrationModel(
    id: 'int-outlook-1',
    userId: 'user-1',
    provider: CalendarProvider.outlook,
    status: status,
    accessToken: 'token-outlook-valido',
    updatedAt: DateTime.now(),
  );
}

void main() {
  // BUG ENCONTRADO E CORRIGIDO NA ETAPA 1.14: `OutlookAuthService._clientId`/
  // `_redirectUri` chamam `dotenv.get(...)`, que LANÇA uma exceção se a
  // chave não existir (comportamento documentado do `flutter_dotenv`) — e
  // essa leitura acontece ANTES de `_authorize` ser chamado, mesmo com um
  // `authorize` falso injetado. Sem carregar o dotenv aqui, TODOS os
  // testes de `connect()` abaixo cairiam no mesmo `catch (_) { return
  // false; }` por causa da exceção do dotenv — inclusive o teste de
  // "sucesso", que esperava `true` e falharia por um motivo que não tem
  // nada a ver com o que o teste diz estar testando. `dotenv.testLoad` é
  // o método oficial do pacote para isso (carrega valores estáticos, sem
  // precisar de um arquivo `.env` real no disco de teste).
  setUpAll(() {
    dotenv.testLoad(fileInput: '''
MICROSOFT_CLIENT_ID=client-id-de-teste
MICROSOFT_REDIRECT_URI=com.bussola.app.test://outlookauth
''');
  });

  group('OutlookAuthService.getValidAccessToken', () {
    test('sem integração salva: devolve null (comportamento sem credenciais)', () async {
      final service = OutlookAuthService(integrationRepository: _FakeIntegrationRepository(null));

      final token = await service.getValidAccessToken('user-1');

      expect(token, isNull);
    });

    test('integração desconectada: devolve null mesmo com um token antigo gravado', () async {
      final repo = _FakeIntegrationRepository(_buildIntegration(status: IntegrationStatus.desconectado));
      final service = OutlookAuthService(integrationRepository: repo);

      final token = await service.getValidAccessToken('user-1');

      expect(token, isNull);
    });

    test('integração conectada: devolve o access_token salvo, consultando o provider outlook', () async {
      final repo = _FakeIntegrationRepository(_buildIntegration(status: IntegrationStatus.conectado));
      final service = OutlookAuthService(integrationRepository: repo);

      final token = await service.getValidAccessToken('user-1');

      expect(token, 'token-outlook-valido');
      expect(repo.providerRecebido, CalendarProvider.outlook);
    });
  });

  group('OutlookAuthService.disconnect', () {
    test('chama o repositório com o provider outlook', () async {
      final repo = _FakeIntegrationRepository();
      final service = OutlookAuthService(integrationRepository: repo);

      await service.disconnect(userId: 'user-1');

      expect(repo.desconectarChamado, true);
      expect(repo.providerRecebido, CalendarProvider.outlook);
    });
  });

  group('OutlookAuthService.connect — sucesso (também valida configuração válida: Client ID/redirect URI presentes)', () {
    test('authorize() devolve code+verifier válidos e a Edge Function responde 200 → connect() devolve true', () async {
      final edgeFunctions = _FakeEdgeFunctionCaller(statusConfigurado: 200);
      final service = OutlookAuthService(
        authorize: (request) async => const AuthorizationResponse(
          authorizationCode: 'codigo-de-autorizacao-simulado',
          codeVerifier: 'code-verifier-simulado',
        ),
        edgeFunctions: edgeFunctions,
        integrationRepository: _FakeIntegrationRepository(),
      );

      final resultado = await service.connect();

      expect(resultado, true);
      expect(edgeFunctions.nomeChamado, 'microsoft-oauth-exchange');
      expect(edgeFunctions.chamadas, 1);
    });
  });

  group('OutlookAuthService.connect — ausência de configuração (Etapa 1.14)', () {
    test('sem MICROSOFT_CLIENT_ID/MICROSOFT_REDIRECT_URI configurados: devolve false, não lança, e NÃO chama a Edge Function', () async {
      // `dotenv.clean()` é o método oficial do pacote para limpar os
      // valores carregados — simula um app sem o App Registration
      // configurado ainda (situação real e esperada até o Azure Portal
      // ser configurado). Restaura o valor de teste depois, para não
      // vazar para os outros testes deste arquivo.
      dotenv.clean();
      addTearDown(() => dotenv.testLoad(fileInput: '''
MICROSOFT_CLIENT_ID=client-id-de-teste
MICROSOFT_REDIRECT_URI=com.bussola.app.test://outlookauth
'''));

      final edgeFunctions = _FakeEdgeFunctionCaller();
      // Mesmo que authorize() "funcionasse", nunca deveria ser chamado —
      // a leitura da configuração falha antes disso.
      final service = OutlookAuthService(
        authorize: (request) async => const AuthorizationResponse(authorizationCode: 'x', codeVerifier: 'y'),
        edgeFunctions: edgeFunctions,
        integrationRepository: _FakeIntegrationRepository(),
      );

      final resultado = await service.connect();

      expect(resultado, false);
      expect(edgeFunctions.chamadas, 0);
    });
  });

  group('OutlookAuthService.connect — cancelamento (exceção lançada por authorize())', () {
    test('devolve false, sem propagar o erro, e NÃO chama a Edge Function', () async {
      final edgeFunctions = _FakeEdgeFunctionCaller();
      final service = OutlookAuthService(
        authorize: (request) async => throw Exception('usuário cancelou o login (simulado)'),
        edgeFunctions: edgeFunctions,
        integrationRepository: _FakeIntegrationRepository(),
      );

      final resultado = await service.connect();

      expect(resultado, false);
      expect(edgeFunctions.chamadas, 0);
    });
  });

  group('OutlookAuthService.connect — erro técnico na interação com a Microsoft', () {
    test('tratado da mesma forma que cancelamento: devolve false, sem lançar, e NÃO chama a Edge Function', () async {
      // Documentado na classe: distinguir "cancelou" de "erro real" de
      // forma confiável exigiria os códigos de erro exatos do SDK nativo
      // da Microsoft/AppAuth por plataforma, que este ambiente não pode
      // verificar — por isso os dois casos são tratados igual.
      final edgeFunctions = _FakeEdgeFunctionCaller();
      final service = OutlookAuthService(
        authorize: (request) async => throw Exception('falha de rede ao abrir o navegador (simulado)'),
        edgeFunctions: edgeFunctions,
        integrationRepository: _FakeIntegrationRepository(),
      );

      final resultado = await service.connect();

      expect(resultado, false);
      expect(edgeFunctions.chamadas, 0);
    });
  });

  group('OutlookAuthService.connect — sem credenciais (branch defensivo)', () {
    test('authorize() devolvendo null: devolve false e NÃO chama a Edge Function', () async {
      // NOTA IMPORTANTE: pela documentação pública do flutter_appauth que
      // consultei, `authorize()` de verdade LANÇA uma exceção em caso de
      // falha/cancelamento — não devolve `null`. Este teste cobre um
      // branch puramente DEFENSIVO do código (`if (resposta == null ...)`)
      // que pode nunca ser alcançado pela implementação real do SDK. Ele
      // continua aqui porque o próprio código aceita esse valor (o tipo
      // injetado é nullable) — mas não deve ser lido como prova de que a
      // Microsoft/flutter_appauth realmente se comporta assim.
      final edgeFunctions = _FakeEdgeFunctionCaller();
      final service = OutlookAuthService(
        authorize: (request) async => null,
        edgeFunctions: edgeFunctions,
        integrationRepository: _FakeIntegrationRepository(),
      );

      final resultado = await service.connect();

      expect(resultado, false);
      expect(edgeFunctions.chamadas, 0);
    });
  });

  group('OutlookAuthService.refreshAccessToken', () {
    test('Edge Function responde 200: sucesso, sem exigir reconexão', () async {
      final service = OutlookAuthService(
        edgeFunctions: _FakeEdgeFunctionCaller(statusConfigurado: 200),
        integrationRepository: _FakeIntegrationRepository(),
      );

      final resultado = await service.refreshAccessToken('user-1');

      expect(resultado.success, true);
      expect(resultado.reconnectRequired, false);
    });

    test('Edge Function responde 401 (refresh_token revogado): falha, exige reconexão', () async {
      final service = OutlookAuthService(
        edgeFunctions: _FakeEdgeFunctionCaller(statusConfigurado: 401),
        integrationRepository: _FakeIntegrationRepository(),
      );

      final resultado = await service.refreshAccessToken('user-1');

      expect(resultado.success, false);
      expect(resultado.reconnectRequired, true);
    });
  });
}

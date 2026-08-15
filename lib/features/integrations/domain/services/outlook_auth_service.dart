import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bussola/core/constants/app_constants.dart';
import 'package:bussola/core/services/edge_function_caller.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/data/repositories/integration_repository.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/services/remote_auth_service.dart';

/// Cuida do login OAuth com a Microsoft (Entra ID) e da obtenção de um
/// `access_token` válido para chamar a Microsoft Graph Calendar API —
/// **nunca** lida com o Client Secret nem com o `refresh_token` (isso é
/// papel exclusivo das Edge Functions `microsoft-oauth-exchange`/
/// `microsoft-oauth-refresh`, que rodam no servidor).
///
/// Implementa [RemoteAuthService] — é essa interface que o
/// `CalendarSyncService` conhece; ninguém além do próprio `connect()`/
/// `disconnect()` precisa saber que esta classe existe.
///
/// Fluxo (decisão técnica aprovada — Authorization Code + PKCE, via
/// `flutter_appauth`, método `authorize()`, NUNCA `authorizeAndExchangeCode()`):
/// 1. `flutter_appauth` abre o navegador do sistema, autentica a pessoa, e
///    devolve só um `authorization code` + o `code_verifier` do PKCE que
///    ele mesmo gerou — nenhum token ainda, nenhum Client Secret envolvido
///    neste passo (é assim que o PKCE evita precisar de um secret no app).
/// 2. Esses dois valores (+ o `redirectUri` usado) são enviados para a
///    Edge Function `microsoft-oauth-exchange`.
/// 3. A Edge Function troca o código pelos tokens junto à Microsoft — só
///    ela conhece o Client Secret — e guarda o `refresh_token` no
///    servidor. Devolve só um status de sucesso para o app.
/// 4. Quando o `access_token` expira, `refreshAccessToken()` chama
///    `microsoft-oauth-refresh`, que usa o `refresh_token` guardado no
///    servidor — de novo, o app nunca vê o `refresh_token`.
///
/// IMPORTANTE (transparência): este fluxo não foi testado contra a
/// Microsoft real neste ambiente — requer um App Registration configurado
/// no Azure Portal (Client ID + Client Secret + redirect URI) e as Edge
/// Functions implantadas. Ver limitações no relatório desta etapa.
class OutlookAuthService implements RemoteAuthService {
  static const List<String> _scopes = ['openid', 'profile', 'offline_access', 'Calendars.ReadWrite'];

  // Documento de descoberta OIDC oficial da Microsoft identity platform —
  // o `flutter_appauth` usa isso para achar os endpoints de autorização e
  // token automaticamente, em vez de precisarmos escrever as URLs na mão.
  static const String _discoveryUrl = 'https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration';

  final Future<AuthorizationResponse?> Function(AuthorizationRequest)? _authorizeOverride;
  final EdgeFunctionCaller _edgeFunctions;
  final IntegrationRepository _integrationRepository;

  /// Preguiçoso de propósito — mesmo padrão do `_googleSignIn` no
  /// `GoogleAuthService`: um `FlutterAppAuth()` real só é construído se
  /// ninguém injetou um substituto (via teste, por exemplo) E `connect()`
  /// for realmente chamado — nunca na hora de instanciar
  /// `OutlookAuthService`. Isso é o que permite um fake deste serviço
  /// existir em teste sem depender de nada de infraestrutura.
  Future<AuthorizationResponse?> Function(AuthorizationRequest) get _authorize =>
      _authorizeOverride ?? FlutterAppAuth().authorize;

  OutlookAuthService({
    Future<AuthorizationResponse?> Function(AuthorizationRequest)? authorize,
    EdgeFunctionCaller? edgeFunctions,
    IntegrationRepository? integrationRepository,
  })  : _authorizeOverride = authorize,
        _edgeFunctions = edgeFunctions ?? const SupabaseEdgeFunctionCaller(),
        _integrationRepository = integrationRepository ?? IntegrationRepository();

  String get _clientId => dotenv.get(AppConstants.microsoftClientIdEnvKey);
  String get _redirectUri => dotenv.get(AppConstants.microsoftRedirectUriEnvKey);

  /// Abre o login da Microsoft, obtém o `authorization code` + `code_verifier`
  /// (PKCE), e manda os dois para a Edge Function trocar por tokens.
  /// Devolve `true` se a conexão foi concluída com sucesso.
  ///
  /// Tratamento de cancelamento/erro: o `flutter_appauth` sinaliza os dois
  /// casos lançando uma exceção (não devolvendo `null`, diferente do
  /// `google_sign_in`) — e os códigos de erro específicos variam por
  /// plataforma (Android/iOS) e não foram verificados contra o SDK real
  /// neste ambiente. Por segurança, tratamos QUALQUER exceção da mesma
  /// forma: "a conexão não foi concluída" (devolve `false`), sem
  /// distinguir cancelamento de erro técnico — distinguir os dois de forma
  /// confiável exigiria testar contra o SDK nativo real, o que este
  /// ambiente não permite.
  ///
  /// Em NENHUM dos casos de falha a Edge Function é chamada — a checagem
  /// acontece antes, então nenhuma tentativa de troca de código chega a
  /// sair do aparelho quando o login não deu certo.
  Future<bool> connect() async {
    AuthorizationResponse? resposta;
    try {
      resposta = await _authorize(AuthorizationRequest(_clientId, _redirectUri, discoveryUrl: _discoveryUrl, scopes: _scopes));
    } catch (_) {
      return false;
    }

    if (resposta == null || resposta.authorizationCode == null || resposta.codeVerifier == null) {
      return false;
    }

    final resultado = await _edgeFunctions.invoke(
      'microsoft-oauth-exchange',
      body: {
        'authorizationCode': resposta.authorizationCode,
        'codeVerifier': resposta.codeVerifier,
        'redirectUri': _redirectUri,
      },
    );

    if (resultado.status != 200) {
      throw Exception('Falha ao concluir a conexão com o Outlook Calendar (${resultado.status}).');
    }

    return true;
  }

  Future<void> disconnect({required String userId}) async {
    await _integrationRepository.disconnect(userId: userId, provider: CalendarProvider.outlook);
  }

  /// Tenta renovar o `access_token` usando o `refresh_token` guardado no
  /// servidor (nunca visto pelo app). Mesma estratégia do Google: se a
  /// Microsoft recusar o refresh (revogado/inválido), a própria Edge
  /// Function já marca a integração como desconectada no banco — aqui só
  /// refletimos isso em [RefreshResult], **sem tentar de novo** (evita loop).
  @override
  Future<RefreshResult> refreshAccessToken(String userId) async {
    try {
      final resposta = await _edgeFunctions.invoke('microsoft-oauth-refresh');

      if (resposta.status == 200) {
        return const RefreshResult(success: true, reconnectRequired: false);
      }

      // 401 com reconnectRequired é o caminho esperado quando o
      // refresh_token foi revogado — não é uma falha "inesperada".
      return const RefreshResult(success: false, reconnectRequired: true);
    } catch (_) {
      // Falha de rede/servidor ao tentar renovar — não sabemos se o
      // refresh_token ainda é válido, então não marcamos como
      // desconectado (evitar desconectar por um problema transitório);
      // só sinaliza falha para quem chamou decidir o que fazer.
      return const RefreshResult(success: false, reconnectRequired: false);
    }
  }

  /// O `access_token` de verdade (o que a Edge Function trocou e guardou)
  /// é lido da tabela `integrations` — nunca pedido de novo ao
  /// `flutter_appauth` diretamente.
  @override
  Future<String?> getValidAccessToken(String userId) async {
    final integration = await _integrationRepository.getIntegration(userId: userId, provider: CalendarProvider.outlook);
    if (integration == null || !integration.isConnected) return null;
    return integration.accessToken;
  }

  /// Status completo da integração (não só o token) — usado pela camada
  /// de apresentação (Etapa 1.10) para saber se está conectado, quando
  /// foi a última sincronização, etc. Mesma consulta que
  /// `getValidAccessToken` já faz internamente, só devolvendo o modelo
  /// inteiro em vez de só o campo do token. Não faz parte do fluxo OAuth
  /// em si — é leitura pura do que já está guardado.
  Future<CalendarIntegrationModel?> getIntegrationStatus(String userId) {
    return _integrationRepository.getIntegration(userId: userId, provider: CalendarProvider.outlook);
  }
}

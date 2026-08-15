import 'package:google_sign_in/google_sign_in.dart';
import 'package:bussola/core/services/supabase_service.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/data/repositories/integration_repository.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/services/remote_auth_service.dart';

/// Cuida do login OAuth com o Google e da obtenção de um `access_token`
/// válido para chamar a Calendar API — **nunca** lida com o Client Secret
/// nem com o `refresh_token` (isso é papel exclusivo das Edge Functions
/// `google-oauth-exchange`/`google-oauth-refresh`, que rodam no servidor).
///
/// Implementa [RemoteAuthService] — é essa interface que o
/// `CalendarSyncService` conhece; ninguém além do próprio `connect()`/
/// `disconnect()` (chamados pelos Use Cases específicos do Google) precisa
/// saber que esta classe existe.
///
/// Fluxo (ver detalhes no relatório desta etapa):
/// 1. `google_sign_in` autentica a pessoa e pede um `serverAuthCode`
///    (com o escopo de Calendar).
/// 2. Esse código é enviado para a Edge Function `google-oauth-exchange`.
/// 3. A Edge Function troca o código pelos tokens junto ao Google e
///    guarda o `refresh_token` no servidor — devolve só um status de
///    sucesso para o app.
/// 4. Quando o `access_token` expira (~1h), `refreshAccessToken()` chama
///    `google-oauth-refresh`, que usa o `refresh_token` guardado no
///    servidor para conseguir um `access_token` novo — de novo, o app
///    nunca vê o `refresh_token`.
///
/// IMPORTANTE (transparência): este fluxo não foi testado contra o Google
/// real neste ambiente — requer um Client ID configurado no Google Cloud
/// Console e as Edge Functions implantadas. Ver limitações no relatório.
class GoogleAuthService implements RemoteAuthService {
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/calendar.readonly',
  ];

  final GoogleSignIn? _googleSignInOverride;
  final IntegrationRepository _integrationRepository;

  /// Preguiçoso de propósito: um `GoogleSignIn()` real só é construído se
  /// ninguém injetou um (via teste, por exemplo) E algum método que
  /// precise dele for realmente chamado — nunca na hora de instanciar
  /// `GoogleAuthService`. Isso é o que permite um fake/mock deste serviço
  /// existir em teste sem depender de nada de infraestrutura.
  GoogleSignIn get _googleSignIn => _googleSignInOverride ?? GoogleSignIn(scopes: _scopes);

  GoogleAuthService({GoogleSignIn? googleSignIn, IntegrationRepository? integrationRepository})
      : _googleSignInOverride = googleSignIn,
        _integrationRepository = integrationRepository ?? IntegrationRepository();

  /// Autentica com o Google e troca o código pelos tokens via Edge
  /// Function. Devolve `true` se a conexão foi concluída com sucesso.
  Future<bool> connect() async {
    final conta = await _googleSignIn.signIn();
    if (conta == null) return false; // pessoa cancelou o login

    final serverAuthCode = conta.serverAuthCode;
    if (serverAuthCode == null) {
      throw StateError('O Google não devolveu um serverAuthCode — verifique a configuração do Client ID.');
    }

    final resposta = await SupabaseService.client.functions.invoke(
      'google-oauth-exchange',
      body: {'serverAuthCode': serverAuthCode},
    );

    if (resposta.status != 200) {
      throw Exception('Falha ao concluir a conexão com o Google Calendar (${resposta.status}).');
    }

    return true;
  }

  Future<void> disconnect({required String userId}) async {
    await _googleSignIn.signOut();
    await _integrationRepository.disconnect(userId: userId, provider: CalendarProvider.googleCalendar);
  }

  /// Tenta renovar o `access_token` usando o `refresh_token` guardado no
  /// servidor (nunca visto pelo app). Se o Google recusar o refresh
  /// (revogado/inválido), a própria Edge Function já marca a integração
  /// como desconectada no banco — aqui só refletimos isso em
  /// [RefreshResult], **sem tentar de novo** (evita loop).
  @override
  Future<RefreshResult> refreshAccessToken(String userId) async {
    try {
      final resposta = await SupabaseService.client.functions.invoke('google-oauth-refresh');

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
  /// `google_sign_in` diretamente, para o app não precisar saber como o
  /// token foi obtido.
  @override
  Future<String?> getValidAccessToken(String userId) async {
    final integration = await _integrationRepository.getIntegration(userId: userId, provider: CalendarProvider.googleCalendar);
    if (integration == null || !integration.isConnected) return null;
    return integration.accessToken;
  }
}

import 'package:bussola/features/integrations/domain/services/google_auth_service.dart';

/// Caso de uso "Conectar Google Calendar". A UI só chama `execute()` —
/// nunca fala com `GoogleAuthService`/`google_sign_in` diretamente.
class ConnectGoogleCalendarUseCase {
  final GoogleAuthService _authService;

  ConnectGoogleCalendarUseCase({GoogleAuthService? authService}) : _authService = authService ?? GoogleAuthService();

  /// Devolve `true` se a conexão foi concluída, `false` se a pessoa
  /// cancelou o login — nunca devolve nem loga nenhum token.
  Future<bool> execute() => _authService.connect();
}

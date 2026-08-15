import 'package:bussola/features/integrations/domain/services/google_auth_service.dart';

class DisconnectGoogleCalendarUseCase {
  final GoogleAuthService _authService;

  DisconnectGoogleCalendarUseCase({GoogleAuthService? authService}) : _authService = authService ?? GoogleAuthService();

  Future<void> execute(String userId) => _authService.disconnect(userId: userId);
}

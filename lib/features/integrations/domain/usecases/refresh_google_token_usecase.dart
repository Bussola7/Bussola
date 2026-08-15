import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/services/google_auth_service.dart';

class RefreshGoogleTokenUseCase {
  final GoogleAuthService _authService;

  RefreshGoogleTokenUseCase({GoogleAuthService? authService}) : _authService = authService ?? GoogleAuthService();

  Future<RefreshResult> execute(String userId) => _authService.refreshAccessToken(userId);
}

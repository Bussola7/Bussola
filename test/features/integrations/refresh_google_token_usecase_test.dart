import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/services/google_auth_service.dart';
import 'package:bussola/features/integrations/domain/usecases/refresh_google_token_usecase.dart';

class _FakeGoogleAuthService extends GoogleAuthService {
  final RefreshResult resultado;

  _FakeGoogleAuthService(this.resultado);

  @override
  Future<RefreshResult> refreshAccessToken(String userId) async => resultado;
}

void main() {
  group('RefreshGoogleTokenUseCase', () {
    test('repassa sucesso quando a renovação funciona', () async {
      final useCase = RefreshGoogleTokenUseCase(
        authService: _FakeGoogleAuthService(const RefreshResult(success: true, reconnectRequired: false)),
      );

      final resultado = await useCase.execute('user-1');

      expect(resultado.success, true);
      expect(resultado.reconnectRequired, false);
    });

    test('sinaliza reconnectRequired quando o refresh_token foi revogado', () async {
      final useCase = RefreshGoogleTokenUseCase(
        authService: _FakeGoogleAuthService(const RefreshResult(success: false, reconnectRequired: true)),
      );

      final resultado = await useCase.execute('user-1');

      expect(resultado.success, false);
      expect(resultado.reconnectRequired, true);
    });
  });
}

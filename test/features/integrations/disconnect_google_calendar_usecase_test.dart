import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/integrations/domain/services/google_auth_service.dart';
import 'package:bussola/features/integrations/domain/usecases/disconnect_google_calendar_usecase.dart';

class _FakeGoogleAuthService extends GoogleAuthService {
  String? userIdRecebido;

  @override
  Future<void> disconnect({required String userId}) async {
    userIdRecebido = userId;
  }
}

void main() {
  test('DisconnectGoogleCalendarUseCase repassa o userId para o service', () async {
    final fake = _FakeGoogleAuthService();
    final useCase = DisconnectGoogleCalendarUseCase(authService: fake);

    await useCase.execute('user-1');

    expect(fake.userIdRecebido, 'user-1');
  });
}

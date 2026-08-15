import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/integrations/domain/services/google_auth_service.dart';
import 'package:bussola/features/integrations/domain/usecases/connect_google_calendar_usecase.dart';

/// Fake do GoogleAuthService — só sobrescreve o método usado pelo Use
/// Case. Graças à inicialização preguiçosa dos Data Sources (auditoria
/// anterior), este fake pode ser construído sem tocar em Supabase,
/// GoogleSignIn ou qualquer infraestrutura real.
class _FakeGoogleAuthService extends GoogleAuthService {
  final bool resultado;
  bool chamado = false;

  _FakeGoogleAuthService({required this.resultado});

  @override
  Future<bool> connect() async {
    chamado = true;
    return resultado;
  }
}

void main() {
  group('ConnectGoogleCalendarUseCase', () {
    test('devolve true quando a conexão é concluída', () async {
      final fake = _FakeGoogleAuthService(resultado: true);
      final useCase = ConnectGoogleCalendarUseCase(authService: fake);

      final resultado = await useCase.execute();

      expect(resultado, true);
      expect(fake.chamado, true);
    });

    test('devolve false quando a pessoa cancela o login (não lança erro)', () async {
      final fake = _FakeGoogleAuthService(resultado: false);
      final useCase = ConnectGoogleCalendarUseCase(authService: fake);

      final resultado = await useCase.execute();

      expect(resultado, false);
    });
  });
}

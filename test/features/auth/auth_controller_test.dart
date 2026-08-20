import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthResponse, User;
import 'package:bussola/features/auth/data/auth_repository.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';

User _buildUser({required String email}) {
  return User(id: 'user-1', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', email: email, createdAt: '2026-08-01T10:00:00.000Z');
}

/// Repositório falso: simula uma "sessão" guardando o usuário atual em
/// memória, sem tocar no Supabase de verdade. Permite forçar falha em
/// cada ação, para testar o tratamento de erro do AuthNotifier.
class _FakeAuthRepository extends AuthRepository {
  User? _currentUser;
  bool falharLogin = false;
  bool falharRegistro = false;
  bool falharResetSenha = false;
  String? lastResetEmail;

  _FakeAuthRepository({User? currentUser}) : _currentUser = currentUser;

  @override
  User? get currentUser => _currentUser;

  @override
  Future<AuthResponse> signInWithEmail({required String email, required String senha}) async {
    if (falharLogin) throw Exception('Credenciais inválidas');
    _currentUser = _buildUser(email: email);
    return AuthResponse(user: _currentUser);
  }

  @override
  Future<AuthResponse> signUpWithEmail({required String nome, required String email, required String senha}) async {
    if (falharRegistro) throw Exception('Falha no cadastro');
    _currentUser = _buildUser(email: email);
    return AuthResponse(user: _currentUser);
  }

  @override
  Future<bool> signInWithGoogle() async {
    _currentUser = _buildUser(email: 'google@bussola.app');
    return true;
  }

  @override
  Future<bool> signInWithApple() async {
    _currentUser = _buildUser(email: 'apple@bussola.app');
    return true;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (falharResetSenha) throw Exception('Falha ao enviar email');
    lastResetEmail = email;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}

void main() {
  group('AuthNotifier.login', () {
    test('sucesso: define o usuário, encerra o loading e limpa o erro', () async {
      final notifier = AuthNotifier(repository: _FakeAuthRepository());

      final ok = await notifier.login(email: 'ana@bussola.app', senha: '123456');

      expect(ok, true);
      expect(notifier.state.user?.email, 'ana@bussola.app');
      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, null);
    });

    test('define isLoading durante a ação, antes de completar', () async {
      final notifier = AuthNotifier(repository: _FakeAuthRepository());

      final future = notifier.login(email: 'ana@bussola.app', senha: '123456');
      expect(notifier.state.isLoading, true);

      await future;
      expect(notifier.state.isLoading, false);
    });

    test('falha: mantém isLoading false e define errorMessage, sem logar o usuário', () async {
      final notifier = AuthNotifier(repository: _FakeAuthRepository()..falharLogin = true);

      final ok = await notifier.login(email: 'ana@bussola.app', senha: 'errada');

      expect(ok, false);
      expect(notifier.state.user, null);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.errorMessage, isNotNull);
    });
  });

  group('AuthNotifier.register', () {
    test('sucesso: define o usuário criado', () async {
      final notifier = AuthNotifier(repository: _FakeAuthRepository());

      final ok = await notifier.register(nome: 'Ana', email: 'ana@bussola.app', senha: '123456');

      expect(ok, true);
      expect(notifier.state.user?.email, 'ana@bussola.app');
    });

    test('falha: define errorMessage e não loga ninguém', () async {
      final notifier = AuthNotifier(repository: _FakeAuthRepository()..falharRegistro = true);

      final ok = await notifier.register(nome: 'Ana', email: 'ana@bussola.app', senha: '123456');

      expect(ok, false);
      expect(notifier.state.user, null);
      expect(notifier.state.errorMessage, isNotNull);
    });
  });

  group('AuthNotifier.loginWithGoogle / loginWithApple', () {
    test('loginWithGoogle define o usuário retornado pelo provedor', () async {
      final notifier = AuthNotifier(repository: _FakeAuthRepository());

      final ok = await notifier.loginWithGoogle();

      expect(ok, true);
      expect(notifier.state.user?.email, 'google@bussola.app');
    });

    test('loginWithApple define o usuário retornado pelo provedor', () async {
      final notifier = AuthNotifier(repository: _FakeAuthRepository());

      final ok = await notifier.loginWithApple();

      expect(ok, true);
      expect(notifier.state.user?.email, 'apple@bussola.app');
    });
  });

  group('AuthNotifier.resetPassword', () {
    test('sucesso: encaminha o email correto para o repositório', () async {
      final repo = _FakeAuthRepository();
      final notifier = AuthNotifier(repository: repo);

      final ok = await notifier.resetPassword('ana@bussola.app');

      expect(ok, true);
      expect(repo.lastResetEmail, 'ana@bussola.app');
    });

    test('falha: define errorMessage', () async {
      final notifier = AuthNotifier(repository: _FakeAuthRepository()..falharResetSenha = true);

      final ok = await notifier.resetPassword('ana@bussola.app');

      expect(ok, false);
      expect(notifier.state.errorMessage, isNotNull);
    });
  });

  group('AuthNotifier.logout', () {
    test('REGRESSÃO: limpa o usuário do estado depois de sair', () async {
      final repo = _FakeAuthRepository(currentUser: _buildUser(email: 'ana@bussola.app'));
      final notifier = AuthNotifier(repository: repo);
      expect(notifier.state.user, isNotNull); // estado inicial já vem logado

      await notifier.logout();

      expect(notifier.state.user, null);
      expect(repo.currentUser, null); // o repositório também não tem mais sessão
    });
  });
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bussola/core/services/supabase_service.dart';

/// Repositório de autenticação: única camada que conversa com o Supabase Auth.
/// Telas e controllers nunca chamam `Supabase.instance` diretamente —
/// sempre passam por aqui, para que a origem dos dados possa mudar sem
/// quebrar o resto do app.
class AuthRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<AuthResponse> signUpWithEmail({
    required String nome,
    required String email,
    required String senha,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: senha,
      data: {'nome': nome},
    );
    return response;
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String senha,
  }) {
    return _client.auth.signInWithPassword(email: email, password: senha);
  }

  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<bool> signInWithApple() {
    return _client.auth.signInWithOAuth(OAuthProvider.apple);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() => _client.auth.signOut();

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}

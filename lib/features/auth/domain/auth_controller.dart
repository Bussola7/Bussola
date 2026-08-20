import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:bussola/features/auth/data/auth_repository.dart';
import 'auth_state.dart';

/// Regra de negócio da autenticação, agora em Riverpod. A tela só chama
/// `ref.read(authNotifierProvider.notifier)` — nunca o [AuthRepository] direto.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier({AuthRepository? repository})
      : _repository = repository ?? AuthRepository(),
        super(AuthState(user: (repository ?? AuthRepository()).currentUser));

  User? get currentUser => _repository.currentUser;

  Future<bool> login({required String email, required String senha}) {
    return _runGuarded(() => _repository.signInWithEmail(email: email, senha: senha));
  }

  Future<bool> register({required String nome, required String email, required String senha}) {
    return _runGuarded(() => _repository.signUpWithEmail(nome: nome, email: email, senha: senha));
  }

  Future<bool> loginWithGoogle() => _runGuarded(() => _repository.signInWithGoogle());

  Future<bool> loginWithApple() => _runGuarded(() => _repository.signInWithApple());

  Future<bool> resetPassword(String email) => _runGuarded(() => _repository.sendPasswordResetEmail(email));

  Future<void> logout() async {
    await _repository.signOut();
    state = state.copyWith(clearUser: true);
  }

  Future<bool> _runGuarded(Future<dynamic> Function() action) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await action();
      state = state.copyWith(isLoading: false, user: _repository.currentUser);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Não foi possível concluir. Verifique os dados e tente novamente.',
      );
      return false;
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

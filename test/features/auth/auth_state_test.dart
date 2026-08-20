import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:bussola/features/auth/domain/auth_state.dart';

User _buildUser({String id = 'user-1'}) {
  return User(id: id, appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '2026-08-01T10:00:00.000Z');
}

void main() {
  group('AuthState.copyWith', () {
    test('troca só o campo pedido e mantém o resto', () {
      const state = AuthState(isLoading: true, errorMessage: 'algo deu errado');
      final atualizado = state.copyWith(isLoading: false);

      expect(atualizado.isLoading, false);
      expect(atualizado.errorMessage, null); // errorMessage sempre é explícito, nunca preservado por padrão
    });

    test('define o usuário quando um novo é passado', () {
      const state = AuthState();
      final user = _buildUser();

      final atualizado = state.copyWith(user: user);

      expect(atualizado.user, user);
    });

    test('REGRESSÃO: clearUser limpa o usuário mesmo que outro campo seja passado junto', () {
      final state = AuthState(user: _buildUser());

      final deslogado = state.copyWith(isLoading: false, clearUser: true);

      expect(deslogado.user, null);
    });

    test('sem clearUser, passar user: null preserva o usuário atual (comportamento normal do ?? )', () {
      final state = AuthState(user: _buildUser());

      final semMudarUsuario = state.copyWith(isLoading: true);

      expect(semMudarUsuario.user, isNotNull);
    });
  });
}

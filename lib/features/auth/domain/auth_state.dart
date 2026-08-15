import 'package:supabase_flutter/supabase_flutter.dart';

/// Estado da autenticação. Imutável — qualquer mudança gera um novo objeto
/// (padrão Riverpod), em vez de mutar campos como no ChangeNotifier antigo.
class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final User? user;

  const AuthState({this.isLoading = false, this.errorMessage, this.user});

  AuthState copyWith({bool? isLoading, String? errorMessage, User? user}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      user: user ?? this.user,
    );
  }
}

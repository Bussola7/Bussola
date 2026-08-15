import 'package:go_router/go_router.dart';
import 'package:bussola/features/auth/presentation/login_screen.dart';
import 'package:bussola/features/auth/presentation/onboarding_screen.dart';
import 'package:bussola/features/auth/presentation/register_screen.dart';
import 'home_shell.dart';
import 'splash_screen.dart';

/// Ponto único de definição das rotas do app. Novas telas (calendário
/// completo, editor de evento, etc.) entram aqui como rotas próprias
/// quando saírem de placeholder.
class AppRouter {
  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(onFinish: () => router.go('/login')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onLoginSuccess: () => router.go('/home'),
          onGoToRegister: () => router.go('/register'),
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(onRegisterSuccess: () => router.go('/home')),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
    ],
  );
}

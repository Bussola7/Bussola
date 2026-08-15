import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/components/app_scaffold.dart';
import 'package:bussola/features/ai/presentation/ai_placeholder_screen.dart';
import 'package:bussola/features/agenda/presentation/screens/calendar_screen.dart';
import 'package:bussola/features/agenda/presentation/screens/create_event_placeholder_screen.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bussola/features/profile/presentation/profile_screen.dart';

/// Casca que une as 5 abas da navegação inferior num único lugar.
/// Cada aba hoje é uma tela real (Hoje, Perfil) ou um placeholder
/// (Agenda, Criar, IA) — trocar o placeholder pela tela final, nas
/// próximas etapas, não exige mexer aqui.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final nome = (authState.user?.userMetadata?['nome'] as String?) ?? 'Usuário';
    final email = authState.user?.email ?? '';
    final userId = authState.user?.id ?? '';

    final screens = [
      DashboardScreen(nomeUsuario: nome, userId: userId),
      const CalendarScreen(),
      const CreateEventPlaceholderScreen(),
      const AiPlaceholderScreen(),
      ProfileScreen(
        nome: nome,
        email: email,
        onLogout: () => ref.read(authNotifierProvider.notifier).logout(),
      ),
    ];

    return AppScaffold(
      currentNavIndex: _index,
      onNavTap: (i) => setState(() => _index = i),
      body: screens[_index],
    );
  }
}

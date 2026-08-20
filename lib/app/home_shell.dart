import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bussola/core/components/app_scaffold.dart';
import 'package:bussola/features/agenda/presentation/screens/calendar_screen.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bussola/features/goals/presentation/screens/goals_screen.dart';
import 'package:bussola/features/performance/presentation/screens/performance_screen.dart';
import 'package:bussola/features/profile/presentation/profile_screen.dart';
import 'package:bussola/features/tasks/presentation/screens/tasks_screen.dart';

/// Casca que une as 5 abas do MVP: Hoje, Tarefas, Agenda, Objetivos,
/// Performance. Perfil/Configurações continuam existindo, só que
/// acessados por um ícone na tela Hoje, não como aba própria — o
/// briefing pede exatamente 5 telas na navegação principal.
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
      DashboardScreen(
        nomeUsuario: nome,
        userId: userId,
        onAbrirPerfil: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              nome: nome,
              email: email,
              onLogout: () async {
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ),
      ),
      const TasksScreen(),
      const CalendarScreen(),
      const GoalsScreen(),
      const PerformanceScreen(),
    ];

    return AppScaffold(
      currentNavIndex: _index,
      onNavTap: (i) => setState(() => _index = i),
      body: screens[_index],
    );
  }
}

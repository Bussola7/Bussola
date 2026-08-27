import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bussola/core/components/app_scaffold.dart';
import 'package:bussola/features/agenda/presentation/screens/calendar_screen.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bussola/features/goals/presentation/screens/goals_screen.dart';
import 'package:bussola/features/profile/presentation/profile_screen.dart';
import 'package:bussola/features/tasks/presentation/screens/tasks_screen.dart';
import 'package:bussola/shared/models/life_area.dart';

/// Casca que une as 5 abas fixas do app: Início, Agenda, Tarefas, Metas
/// e Perfil. Sem botão central de criação — cada tela tem seu próprio
/// jeito de criar (a Hoje tem o bloco "Criar", Agenda/Tarefas/Metas têm
/// FAB ou botão próprio).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  // Filtro de área aplicado à próxima vez que a aba correspondente for
  // aberta (vindo do menu "Áreas da vida" da Hoje). Como `screens[_index]`
  // reconstrói a tela do zero a cada troca (não é IndexedStack), passar um
  // valor novo no construtor já basta para reaplicar o filtro.
  LifeArea? _filtroAgenda;
  LifeArea? _filtroTarefas;
  LifeArea? _filtroMetas;

  void _navigateToTab(int index, {LifeArea? filtro}) {
    setState(() {
      _index = index;
      switch (index) {
        case 1:
          _filtroAgenda = filtro;
          break;
        case 2:
          _filtroTarefas = filtro;
          break;
        case 3:
          _filtroMetas = filtro;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final nome = (authState.user?.userMetadata?['nome'] as String?) ?? 'Usuário';
    final email = authState.user?.email ?? '';
    final userId = authState.user?.id ?? '';

    final screens = [
      DashboardScreen(nomeUsuario: nome, userId: userId, onNavigateToTab: _navigateToTab),
      CalendarScreen(
        key: ValueKey('agenda-$_filtroAgenda'),
        filtroInicial: _filtroAgenda,
        onFiltroLimpo: () => setState(() => _filtroAgenda = null),
      ),
      TasksScreen(
        key: ValueKey('tarefas-$_filtroTarefas'),
        filtroInicial: _filtroTarefas,
        onFiltroLimpo: () => setState(() => _filtroTarefas = null),
      ),
      GoalsScreen(
        key: ValueKey('metas-$_filtroMetas'),
        filtroInicial: _filtroMetas,
        onFiltroLimpo: () => setState(() => _filtroMetas = null),
      ),
      ProfileScreen(
        nome: nome,
        email: email,
        onLogout: () async {
          await ref.read(authNotifierProvider.notifier).logout();
          if (context.mounted) context.go('/login');
        },
      ),
    ];

    return AppScaffold(
      currentNavIndex: _index,
      onNavTap: (i) => setState(() => _index = i),
      body: screens[_index],
    );
  }
}

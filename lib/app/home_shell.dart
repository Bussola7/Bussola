import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bussola/core/components/app_scaffold.dart';
import 'package:bussola/features/agenda/domain/entities/event_entity.dart';
import 'package:bussola/features/agenda/domain/services/calendar_service.dart';
import 'package:bussola/features/agenda/presentation/screens/calendar_screen.dart';
import 'package:bussola/features/agenda/presentation/screens/event_editor_screen.dart';
import 'package:bussola/features/agenda/presentation/widgets/bussola_fab.dart';
import 'package:bussola/features/auth/domain/auth_controller.dart';
import 'package:bussola/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bussola/features/goals/presentation/screens/goals_screen.dart';
import 'package:bussola/features/profile/presentation/profile_screen.dart';
import 'package:bussola/features/tasks/presentation/widgets/task_form_sheet.dart';

/// Casca que une as 3 abas persistentes do app: Início, Agenda, Metas.
/// Tarefas e Perfil abrem por cima (push), e o botão central "+" oferece
/// criação rápida (tarefa ou compromisso) sem precisar navegar até a
/// aba certa primeiro.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _calendarService = CalendarService();
  int _index = 0;

  void _abrirPerfil(String nome, String email) {
    Navigator.of(context).push(
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
    );
  }

  Future<void> _criacaoRapida(String userId) async {
    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Nova tarefa'),
              onTap: () => Navigator.of(context).pop('tarefa'),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Novo compromisso'),
              onTap: () => Navigator.of(context).pop('evento'),
            ),
          ],
        ),
      ),
    );
    if (escolha == null || !mounted) return;

    if (escolha == 'tarefa') {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => TaskFormSheet(userId: userId),
      );
      return;
    }

    final calendar = await _calendarService.getOrCreateDefaultCalendar(userId);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EventEditorScreen(calendarId: calendar.id, userId: userId, initialDate: DateTime.now()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final nome = (authState.user?.userMetadata?['nome'] as String?) ?? 'Usuário';
    final email = authState.user?.email ?? '';
    final userId = authState.user?.id ?? '';

    final screens = [
      DashboardScreen(nomeUsuario: nome, userId: userId, onNavigateToTab: (i) => setState(() => _index = i)),
      const CalendarScreen(),
      const GoalsScreen(),
    ];

    return AppScaffold(
      currentNavIndex: _index,
      onNavTap: (i) => setState(() => _index = i),
      onPerfilTap: () => _abrirPerfil(nome, email),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: BussolaFab(onPressed: () => _criacaoRapida(userId), tooltip: 'Criar'),
      body: screens[_index],
    );
  }
}

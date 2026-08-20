import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';

/// Navegação inferior do app: Hoje, Tarefas, Agenda, Objetivos, Performance.
class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: 'Hoje'),
        BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), activeIcon: Icon(Icons.check_circle), label: 'Tarefas'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'Agenda'),
        BottomNavigationBarItem(icon: Icon(Icons.flag_outlined), activeIcon: Icon(Icons.flag), label: 'Objetivos'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Performance'),
      ],
    );
  }
}

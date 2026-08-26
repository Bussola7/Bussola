import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';

/// Navegação inferior do app: Início, [espaço pro botão central de criar,
/// que é um FloatingActionButton "centerDocked" do Scaffold — não faz
/// parte desta barra], Perfil.
///
/// Agenda e Metas saíram daqui — já existem como atalhos no header da
/// Hoje, então ficavam duplicados nos dois lugares. Só Início é aba de
/// verdade (mantém estado, tem `currentIndex`) — Perfil abre por cima
/// (como já fazia antes, quando era só um ícone na Hoje).
class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onPerfilTap;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onPerfilTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppColors.surfaceLight,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Início',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
            ),
            const SizedBox(width: 56), // espaço reservado pro FAB central
            Expanded(
              child: _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Perfil',
                selected: false,
                onTap: onPerfilTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cor = selected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? activeIcon : icon, color: cor, size: 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: cor, fontSize: 11)),
        ],
      ),
    );
  }
}

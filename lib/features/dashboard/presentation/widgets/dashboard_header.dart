import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';

/// Header em gradiente da tela Hoje: só saudação + notificações/mensagens.
/// Os atalhos rápidos que ficavam aqui saíram — Agenda/Tarefas/Metas já
/// são abas da navegação inferior, e duplicavam o caminho. Sino e balão
/// de chat ainda não têm uma feature por trás — avisam "Em breve" ao
/// tocar, em vez de fingir que fazem algo.
class DashboardHeader extends StatelessWidget {
  final String nomeUsuario;

  const DashboardHeader({super.key, required this.nomeUsuario});

  void _emBreve(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Em breve.')));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.explore, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Olá, $nomeUsuario',
              style: AppTextStyles.heading2.copyWith(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => _emBreve(context),
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () => _emBreve(context),
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

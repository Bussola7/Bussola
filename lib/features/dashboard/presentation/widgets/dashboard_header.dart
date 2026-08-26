import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';

/// Header em gradiente da tela Hoje: saudação + notificações/mensagens +
/// atalhos rápidos para as outras áreas do app. Sino e balão de chat
/// ainda não têm uma feature por trás — avisam "Em breve" ao tocar, em
/// vez de fingir que fazem algo.
class DashboardHeader extends StatelessWidget {
  final String nomeUsuario;
  final VoidCallback onTapTarefas;
  final VoidCallback onTapMetas;
  final VoidCallback onTapAgenda;

  const DashboardHeader({
    super.key,
    required this.nomeUsuario,
    required this.onTapTarefas,
    required this.onTapMetas,
    required this.onTapAgenda,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: _AtalhoRapido(icon: Icons.explore_outlined, label: 'Hoje')),
              Expanded(child: _AtalhoRapido(icon: Icons.check_circle_outline, label: 'Tarefas', onTap: onTapTarefas)),
              Expanded(child: _AtalhoRapido(icon: Icons.flag_outlined, label: 'Metas', onTap: onTapMetas)),
              Expanded(child: _AtalhoRapido(icon: Icons.calendar_today_outlined, label: 'Agenda', onTap: onTapAgenda)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AtalhoRapido extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _AtalhoRapido({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

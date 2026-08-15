import 'package:flutter/material.dart';
import 'package:bussola/core/components/app_card.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/settings/presentation/settings_screen.dart';

/// Tela de Perfil. Nesta sprint mostra só os dados básicos do usuário
/// logado; edição de perfil e preferências avançadas ficam para depois.
class ProfileScreen extends StatelessWidget {
  final String nome;
  final String email;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.nome,
    required this.email,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 32, backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white, size: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome, style: AppTextStyles.heading2),
                    Text(email, style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_outlined, color: AppColors.textMuted),
              title: Text('Configurações', style: AppTextStyles.body),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: Text('Sair', style: AppTextStyles.body.copyWith(color: AppColors.error)),
              onTap: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

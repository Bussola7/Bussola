import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_text_styles.dart';

/// Tela de Configurações. Notificações, modo escuro e idioma ainda são só
/// estrutura visual — persistir essas preferências fica para uma próxima
/// etapa.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Configurações', style: AppTextStyles.heading1),
        const SizedBox(height: 24),
        SwitchListTile(
          value: true,
          onChanged: (_) {},
          title: Text('Notificações', style: AppTextStyles.body),
        ),
        SwitchListTile(
          value: false,
          onChanged: (_) {},
          title: Text('Modo escuro', style: AppTextStyles.body),
        ),
        ListTile(
          title: Text('Idioma', style: AppTextStyles.body),
          trailing: Text('Português', style: AppTextStyles.bodyMuted),
        ),
      ],
    );
  }
}

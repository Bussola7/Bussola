import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/settings/data/settings_repository.dart';
import 'package:bussola/features/settings/presentation/providers/settings_provider.dart';

/// Tela de Configurações. Notificações, modo escuro e idioma são
/// persistidos localmente (shared_preferences) e reaplicados ao abrir o
/// app de novo — modo escuro também já muda o tema de verdade.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Configurações', style: AppTextStyles.heading1),
        const SizedBox(height: 24),
        SwitchListTile(
          value: settings.notificationsEnabled,
          onChanged: notifier.setNotificationsEnabled,
          title: Text('Notificações', style: AppTextStyles.body),
        ),
        SwitchListTile(
          value: settings.darkModeEnabled,
          onChanged: notifier.setDarkModeEnabled,
          title: Text('Modo escuro', style: AppTextStyles.body),
        ),
        ListTile(
          title: Text('Idioma', style: AppTextStyles.body),
          trailing: Text(settings.language.label, style: AppTextStyles.bodyMuted),
          onTap: () => _abrirSeletorIdioma(context, settings.language, notifier),
        ),
      ],
    );
  }

  Future<void> _abrirSeletorIdioma(BuildContext context, AppLanguage atual, SettingsNotifier notifier) {
    return showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppLanguage.values.map((idioma) {
            return ListTile(
              title: Text(idioma.label),
              subtitle: idioma.isAvailable ? null : const Text('Em breve'),
              trailing: idioma == atual ? const Icon(Icons.check) : null,
              enabled: idioma.isAvailable,
              onTap: idioma.isAvailable
                  ? () {
                      notifier.setLanguage(idioma);
                      Navigator.of(context).pop();
                    }
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }
}

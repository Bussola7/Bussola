import 'package:shared_preferences/shared_preferences.dart';

/// Idiomas que aparecem no seletor de Configurações. Só [portugues] tem
/// telas de verdade traduzidas hoje — os outros existem na lista como
/// preparação (aparecem desabilitados, "em breve"), para quando a
/// tradução completa do app for priorizada.
enum AppLanguage { portugues, ingles, espanhol }

extension AppLanguageX on AppLanguage {
  static AppLanguage fromCode(String? code) {
    switch (code) {
      case 'en':
        return AppLanguage.ingles;
      case 'es':
        return AppLanguage.espanhol;
      case 'pt':
      default:
        return AppLanguage.portugues;
    }
  }

  String get code {
    switch (this) {
      case AppLanguage.portugues:
        return 'pt';
      case AppLanguage.ingles:
        return 'en';
      case AppLanguage.espanhol:
        return 'es';
    }
  }

  String get label {
    switch (this) {
      case AppLanguage.portugues:
        return 'Português';
      case AppLanguage.ingles:
        return 'English';
      case AppLanguage.espanhol:
        return 'Español';
    }
  }

  bool get isAvailable => this == AppLanguage.portugues;
}

/// Guarda as preferências de Configurações (notificações, modo escuro,
/// idioma) localmente no dispositivo, via `shared_preferences` — não são
/// dados do usuário que precisem estar no Supabase.
class SettingsRepository {
  static const _keyNotifications = 'settings_notifications_enabled';
  static const _keyDarkMode = 'settings_dark_mode_enabled';
  static const _keyLanguage = 'settings_language';

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifications) ?? true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, value);
  }

  Future<bool> getDarkModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? false;
  }

  Future<void> setDarkModeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }

  Future<AppLanguage> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return AppLanguageX.fromCode(prefs.getString(_keyLanguage));
  }

  Future<void> setLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language.code);
  }
}

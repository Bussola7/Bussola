import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bussola/features/settings/data/settings_repository.dart';

void main() {
  group('SettingsRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getNotificationsEnabled retorna true por padrão quando nunca foi salvo', () async {
      expect(await SettingsRepository().getNotificationsEnabled(), true);
    });

    test('setNotificationsEnabled/getNotificationsEnabled fazem round-trip', () async {
      final repo = SettingsRepository();
      await repo.setNotificationsEnabled(false);
      expect(await repo.getNotificationsEnabled(), false);
    });

    test('getDarkModeEnabled retorna false por padrão quando nunca foi salvo', () async {
      expect(await SettingsRepository().getDarkModeEnabled(), false);
    });

    test('setDarkModeEnabled/getDarkModeEnabled fazem round-trip', () async {
      final repo = SettingsRepository();
      await repo.setDarkModeEnabled(true);
      expect(await repo.getDarkModeEnabled(), true);
    });

    test('getLanguage retorna português por padrão quando nunca foi salvo', () async {
      expect(await SettingsRepository().getLanguage(), AppLanguage.portugues);
    });

    test('setLanguage/getLanguage fazem round-trip', () async {
      final repo = SettingsRepository();
      await repo.setLanguage(AppLanguage.ingles);
      expect(await repo.getLanguage(), AppLanguage.ingles);
    });

    test('as preferências persistem entre instâncias diferentes do repositório (mesmo armazenamento)', () async {
      await SettingsRepository().setDarkModeEnabled(true);
      expect(await SettingsRepository().getDarkModeEnabled(), true);
    });
  });

  group('AppLanguageX', () {
    test('só português está disponível hoje', () {
      expect(AppLanguage.portugues.isAvailable, true);
      expect(AppLanguage.ingles.isAvailable, false);
      expect(AppLanguage.espanhol.isAvailable, false);
    });

    test('fromCode reconhece os códigos salvos e cai para português em código desconhecido ou nulo', () {
      expect(AppLanguageX.fromCode('en'), AppLanguage.ingles);
      expect(AppLanguageX.fromCode('es'), AppLanguage.espanhol);
      expect(AppLanguageX.fromCode('pt'), AppLanguage.portugues);
      expect(AppLanguageX.fromCode(null), AppLanguage.portugues);
      expect(AppLanguageX.fromCode('fr'), AppLanguage.portugues);
    });
  });
}

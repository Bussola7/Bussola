import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/settings/data/settings_repository.dart';
import 'package:bussola/features/settings/presentation/providers/settings_provider.dart';

/// Repositório falso: guarda as preferências em memória, sem tocar no
/// shared_preferences de verdade.
class _FakeSettingsRepository extends SettingsRepository {
  bool notifications = true;
  bool darkMode = false;
  AppLanguage language = AppLanguage.portugues;

  @override
  Future<bool> getNotificationsEnabled() async => notifications;

  @override
  Future<void> setNotificationsEnabled(bool value) async => notifications = value;

  @override
  Future<bool> getDarkModeEnabled() async => darkMode;

  @override
  Future<void> setDarkModeEnabled(bool value) async => darkMode = value;

  @override
  Future<AppLanguage> getLanguage() async => language;

  @override
  Future<void> setLanguage(AppLanguage value) async => language = value;
}

Future<void> _flushMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  group('SettingsNotifier', () {
    test('começa carregando e assume os valores salvos assim que o repositório responde', () async {
      final repo = _FakeSettingsRepository()
        ..notifications = false
        ..darkMode = true;
      final notifier = SettingsNotifier(repository: repo);

      expect(notifier.state.isLoading, true); // ainda não deu tempo do repositório responder

      await _flushMicrotasks();

      expect(notifier.state.isLoading, false);
      expect(notifier.state.notificationsEnabled, false);
      expect(notifier.state.darkModeEnabled, true);
    });

    test('setNotificationsEnabled atualiza o estado e persiste no repositório', () async {
      final repo = _FakeSettingsRepository();
      final notifier = SettingsNotifier(repository: repo);
      await _flushMicrotasks();

      await notifier.setNotificationsEnabled(false);

      expect(notifier.state.notificationsEnabled, false);
      expect(repo.notifications, false);
    });

    test('setDarkModeEnabled atualiza o estado e persiste no repositório', () async {
      final repo = _FakeSettingsRepository();
      final notifier = SettingsNotifier(repository: repo);
      await _flushMicrotasks();

      await notifier.setDarkModeEnabled(true);

      expect(notifier.state.darkModeEnabled, true);
      expect(repo.darkMode, true);
    });

    test('setLanguage atualiza o estado e persiste no repositório', () async {
      final repo = _FakeSettingsRepository();
      final notifier = SettingsNotifier(repository: repo);
      await _flushMicrotasks();

      await notifier.setLanguage(AppLanguage.ingles);

      expect(notifier.state.language, AppLanguage.ingles);
      expect(repo.language, AppLanguage.ingles);
    });
  });
}

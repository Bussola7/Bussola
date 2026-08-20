import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/features/settings/data/settings_repository.dart';

class SettingsState {
  final bool notificationsEnabled;
  final bool darkModeEnabled;
  final AppLanguage language;
  final bool isLoading;

  const SettingsState({
    this.notificationsEnabled = true,
    this.darkModeEnabled = false,
    this.language = AppLanguage.portugues,
    this.isLoading = true,
  });

  SettingsState copyWith({
    bool? notificationsEnabled,
    bool? darkModeEnabled,
    AppLanguage? language,
    bool? isLoading,
  }) {
    return SettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      language: language ?? this.language,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Carrega e persiste as Configurações. O estado inicial usa os mesmos
/// padrões que a tela sempre mostrou (notificações ligadas, modo claro,
/// Português) até o `shared_preferences` responder — evita a tela
/// "piscar" com valores diferentes do que o usuário provavelmente já vê.
class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repository;

  SettingsNotifier({SettingsRepository? repository})
      : _repository = repository ?? SettingsRepository(),
        super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final notifications = await _repository.getNotificationsEnabled();
    final darkMode = await _repository.getDarkModeEnabled();
    final language = await _repository.getLanguage();
    state = state.copyWith(
      notificationsEnabled: notifications,
      darkModeEnabled: darkMode,
      language: language,
      isLoading: false,
    );
  }

  Future<void> setNotificationsEnabled(bool value) async {
    state = state.copyWith(notificationsEnabled: value);
    await _repository.setNotificationsEnabled(value);
  }

  Future<void> setDarkModeEnabled(bool value) async {
    state = state.copyWith(darkModeEnabled: value);
    await _repository.setDarkModeEnabled(value);
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
    await _repository.setLanguage(language);
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) => SettingsNotifier());

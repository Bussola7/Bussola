/// Textos e valores fixos usados em mais de um lugar do app.
/// Evita "strings soltas" espalhadas pelas telas.
class AppConstants {
  AppConstants._();

  static const String appName = 'Bússola';
  static const String appTagline = 'Seu tempo. Sua direção.';

  static const String supabaseUrlEnvKey = 'SUPABASE_URL';
  static const String supabaseAnonKeyEnvKey = 'SUPABASE_ANON_KEY';

  // Nomes das tabelas do Supabase — centralizados para evitar erro de digitação
  // espalhado pelos repositórios.
  static const String tableProfiles = 'profiles';
  static const String tableSettings = 'settings';
  static const String tableUserPreferences = 'user_preferences';
  static const String tableTasks = 'tasks';
  static const String tableGoals = 'goals';
}

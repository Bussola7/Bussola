/// Textos e valores fixos usados em mais de um lugar do app.
/// Evita "strings soltas" espalhadas pelas telas.
class AppConstants {
  AppConstants._();

  static const String appName = 'Bússola';
  static const String appTagline = 'Seu tempo. Sua direção.';

  static const String supabaseUrlEnvKey = 'SUPABASE_URL';
  static const String supabaseAnonKeyEnvKey = 'SUPABASE_ANON_KEY';

  // Microsoft Entra ID (Outlook Calendar) — Client ID e redirect URI NÃO
  // são segredos (são públicos por natureza no fluxo OAuth com PKCE de
  // app nativo) — por isso podem viver no .env, como a URL do Supabase.
  // O Client Secret NUNCA aparece aqui — só existe nas Edge Functions.
  static const String microsoftClientIdEnvKey = 'MICROSOFT_CLIENT_ID';
  static const String microsoftRedirectUriEnvKey = 'MICROSOFT_REDIRECT_URI';

  // Nomes das tabelas do Supabase — centralizados para evitar erro de digitação
  // espalhado pelos repositórios.
  static const String tableProfiles = 'profiles';
  static const String tableSettings = 'settings';
  static const String tableIntegrations = 'integrations';
  static const String tableUserPreferences = 'user_preferences';
}

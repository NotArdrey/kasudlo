class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const passwordResetRedirectUrl = String.fromEnvironment(
    'PASSWORD_RESET_REDIRECT_URL',
    defaultValue: 'com.kasudlo.kasudlo://login-callback',
  );
  static const groqApiKey = String.fromEnvironment('GROQ_API_KEY');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
  static bool get hasGroq => groqApiKey.isNotEmpty;
}

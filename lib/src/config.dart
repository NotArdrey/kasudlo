class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const groqApiKey = String.fromEnvironment('GROQ_API_KEY');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
  static bool get hasGroq => groqApiKey.isNotEmpty;
}

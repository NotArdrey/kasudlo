class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ombfilswymuhsaovefuc.supabase.co',
  );
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9tYmZpbHN3eW11aHNhb3ZlZnVjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1MzU4NDEsImV4cCI6MjA5NTExMTg0MX0.1LaDW6GkH-QYYSLIRQO0Pu8vIy3JG7reDNnVPHxucHk',
  );
  static const passwordResetRedirectUrl = String.fromEnvironment(
    'PASSWORD_RESET_REDIRECT_URL',
    defaultValue: 'com.kasudlo.kasudlo://login-callback',
  );
  static const groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
  static bool get hasGroq => groqApiKey.isNotEmpty;
}

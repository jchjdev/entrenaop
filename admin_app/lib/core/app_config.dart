abstract final class AppConfig {
  static const _environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://sxbxfjqgoddzhtcyhalw.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_n6qWrY5f6dG_3fJpXwctZQ_Nlvu_x7Z',
  );

  static void validate() {
    if (_environment != 'development' && _environment != 'production') {
      throw StateError('APP_ENV no válido: $_environment');
    }
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError('Falta la configuración pública de Supabase.');
    }
    if (_environment == 'production' &&
        supabaseUrl.contains('sxbxfjqgoddzhtcyhalw')) {
      throw StateError('El panel de producción no puede usar EntrenaOP Dev.');
    }
  }
}

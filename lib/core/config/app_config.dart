enum AppEnvironment { development, production }

abstract final class AppConfig {
  static const _environmentName = String.fromEnvironment(
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

  static AppEnvironment get environment => switch (_environmentName) {
    'development' => AppEnvironment.development,
    'production' => AppEnvironment.production,
    _ => throw StateError('APP_ENV no válido: $_environmentName'),
  };

  static void validate() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError('Falta la configuración pública de Supabase.');
    }

    if (environment == AppEnvironment.production &&
        supabaseUrl.contains('sxbxfjqgoddzhtcyhalw')) {
      throw StateError(
        'Una compilación de producción no puede usar EntrenaOP Dev.',
      );
    }
  }
}

import 'package:entrenaop/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la configuración predeterminada usa EntrenaOP Dev', () {
    expect(AppConfig.environment, AppEnvironment.development);
    expect(AppConfig.supabaseUrl, contains('sxbxfjqgoddzhtcyhalw'));
    expect(() => AppConfig.validate(), returnsNormally);
  });
}

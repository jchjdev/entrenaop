import 'package:entrenaop/core/config/app_build_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'lee versión y build reales sin afirmar revisión ni actualización',
    () async {
      PackageInfo.setMockInitialValues(
        appName: 'EntrenaOP',
        packageName: 'test.entrenaop',
        version: '1.8.3',
        buildNumber: '42',
        buildSignature: '',
      );
      final info = await AppBuildInfo.load();
      expect(info.versionLabel, 'Versión 1.8.3 · compilación 42');
      expect(info.revision, isNull);
      expect(info.builtAt, isNull);
      expect(info.modifiedSources, isNull);
      expect(info.revisionLabel, 'Sin identificar');
      expect(info.diagnosticText, contains('Fuentes: sin identificar'));
      expect(info.diagnosticText, isNot(contains('actualizado')));
    },
  );

  test('datos ausentes no inventan la versión de pubspec', () async {
    PackageInfo.setMockInitialValues(
      appName: '',
      packageName: '',
      version: '',
      buildNumber: '',
      buildSignature: '',
    );
    final info = await AppBuildInfo.load();
    expect(info.versionLabel, 'Versión no disponible');
  });
}

import 'package:package_info_plus/package_info_plus.dart';

/// Datos ficticios para capturas de widgets sin consultar plugins nativos.
void setUpVisualAppIdentity() => PackageInfo.setMockInitialValues(
  appName: 'EntrenaOP',
  packageName: 'es.entrenaop.app',
  version: '1.0.0',
  buildNumber: '2',
  buildSignature: '',
);

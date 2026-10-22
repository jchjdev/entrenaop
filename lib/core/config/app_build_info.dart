import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_config.dart';

/// Identifica lo instalado; una revisión ausente nunca equivale a «actualizado».
class AppBuildInfo {
  const AppBuildInfo({
    required this.version,
    required this.buildNumber,
    required this.environment,
    required this.mode,
    this.revision,
    this.builtAt,
    this.modifiedSources,
  });

  final String? version;
  final String? buildNumber;
  final String environment;
  final String mode;
  final String? revision;
  final DateTime? builtAt;
  final bool? modifiedSources;

  String get versionLabel => version == null
      ? 'Versión no disponible'
      : 'Versión $version · compilación ${buildNumber ?? 'sin identificar'}';

  String get revisionLabel => revision == null
      ? 'Sin identificar'
      : '${revision!.substring(0, 8)}${modifiedSources == true ? ' · cambios locales' : ''}';

  String get diagnosticText => [
    'EntrenaOP',
    versionLabel,
    'Entorno: $environment',
    'Modo: $mode',
    'Revisión: ${revision ?? 'sin identificar'}',
    'Fuentes: ${switch (modifiedSources) {
      true => 'con cambios locales',
      false => 'guardadas en Git',
      null => 'sin identificar',
    }}',
    'Preparada: ${builtAt?.toUtc().toIso8601String() ?? 'fecha no disponible'}',
  ].join('\n');

  static Future<AppBuildInfo> load() async {
    String? version, build;
    try {
      // Lee el paquete real: respeta --build-name y --build-number de Flutter.
      final package = await PackageInfo.fromPlatform();
      version = package.version.trim().isEmpty ? null : package.version;
      build = package.buildNumber.trim().isEmpty ? null : package.buildNumber;
    } catch (_) {
      // Un diagnóstico no puede impedir abrir el perfil ni inventar una versión.
    }
    const revision = String.fromEnvironment('APP_REVISION');
    const sourceState = String.fromEnvironment('APP_SOURCE_DIRTY');
    const buildTime = String.fromEnvironment('APP_BUILD_TIME');
    return AppBuildInfo(
      version: version,
      buildNumber: build,
      environment: AppConfig.environment == AppEnvironment.development
          ? 'Desarrollo (Dev)'
          : 'Producción',
      mode: kReleaseMode ? 'Release' : (kProfileMode ? 'Profile' : 'Debug'),
      revision: RegExp(r'^[0-9a-f]{40}$').hasMatch(revision) ? revision : null,
      modifiedSources: switch (sourceState) {
        'true' => true,
        'false' => false,
        _ => null,
      },
      builtAt: buildTime.endsWith('Z') ? DateTime.tryParse(buildTime) : null,
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_build_info.dart';
import '../domain/app_support.dart';

abstract final class PlatformAppSupport {
  static Uri? _https(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri
        : null;
  }

  static final resources = AppSupportResources(
    instagram: _https(const String.fromEnvironment('APP_INSTAGRAM_URL')),
    rating: _https(const String.fromEnvironment('APP_RATING_URL')),
    promotion: _https(
      const String.fromEnvironment('APP_PROMOTION_REDEMPTION_URL'),
    ),
  );

  static Future<bool> open(Uri uri) async {
    if (uri.scheme != 'https' && uri.scheme != 'mailto') return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<String> diagnostic() async =>
      '${(await AppBuildInfo.load()).diagnosticText}\nPlataforma: ${kIsWeb ? 'Web' : defaultTargetPlatform.name}';
}

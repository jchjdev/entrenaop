/// Devuelve al mismo navegador en web y a la app instalada en móvil.
abstract final class AuthRedirect {
  static const mobileCallback = 'es.entrenaop://auth-callback/';

  static String resolve({
    required bool isWeb,
    required Uri baseUri,
    required bool isProduction,
    String configuredUrl = '',
  }) {
    final target = configuredUrl.isNotEmpty
        ? Uri.parse(configuredUrl)
        : isWeb
        ? Uri(
            scheme: baseUri.scheme,
            userInfo: baseUri.userInfo,
            host: baseUri.host,
            port: baseUri.hasPort ? baseUri.port : null,
            path: baseUri.path,
          )
        : Uri.parse(mobileCallback);
    final local = target.host == 'localhost' || target.host == '127.0.0.1';
    if ((target.host.isEmpty && target.toString() != mobileCallback) ||
        target.userInfo.isNotEmpty ||
        target.hasQuery ||
        target.hasFragment ||
        (target.scheme != 'https' &&
            !(target.scheme == 'http' && local && !isProduction) &&
            target.toString() != mobileCallback) ||
        (isProduction && local)) {
      throw StateError(
        'Redirección de autenticación no válida para el entorno.',
      );
    }
    return target.toString();
  }
}

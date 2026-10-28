/// Solo enlaces propios. El secreto va en el fragmento y nunca en la petición
/// HTTP de la página. «invitation» evita colisionar con el «code» PKCE de Auth.
abstract final class TrainerInvitationLink {
  static bool validSecret(String value) =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
  static bool validEmail(String value) =>
      value.length <= 254 &&
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value) &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);
  static Uri share(String secret) {
    if (!validSecret(secret)) throw ArgumentError('Invitación no válida.');
    return Uri.https('trainer.entrenaop.es', '/').replace(
      fragment: Uri(
        path: '/invite',
        queryParameters: {'invitation': secret},
      ).toString(),
    );
  }

  static Uri openApp(String secret) {
    if (!validSecret(secret)) throw ArgumentError('Invitación no válida.');
    return Uri(
      scheme: 'es.entrenaop',
      host: 'trainer-invitation',
      path: '/',
      fragment: Uri(queryParameters: {'invitation': secret}).query,
    );
  }

  static bool isInvitation(Uri uri) =>
      (uri.scheme == 'es.entrenaop' && uri.host == 'trainer-invitation') ||
      (uri.scheme == 'https' &&
          uri.host == 'trainer.entrenaop.es' &&
          uri.fragment.split('?').first == '/invite');
  static String? fromRoute(Uri route) {
    if (route.path != '/invite' ||
        route.hasFragment ||
        route.queryParametersAll.length != 1) {
      return null;
    }
    final values = route.queryParametersAll['invitation'];
    return values?.length == 1 && validSecret(values!.single)
        ? values.single
        : null;
  }

  static String? fromInput(String raw) {
    final value = raw.trim();
    if (validSecret(value)) return value;
    try {
      return parse(Uri.parse(value));
    } on FormatException {
      return null;
    }
  }

  static String? parse(Uri uri) {
    if (uri.toString().length > 512 ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery) {
      return null;
    }
    try {
      if (uri.scheme == 'es.entrenaop' &&
          uri.host == 'trainer-invitation' &&
          uri.path == '/') {
        return fromRoute(Uri.parse('/invite?${uri.fragment}'));
      }
      if (uri.scheme == 'https' &&
          uri.host == 'trainer.entrenaop.es' &&
          uri.path == '/') {
        return fromRoute(Uri.parse(uri.fragment));
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

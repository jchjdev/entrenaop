/// La invitación tiene prioridad sobre la bienvenida y conserva su contexto
/// durante el acceso/registro. No permite destinos de retorno arbitrarios.
class EntryNavigation {
  String? _pendingInvitation;
  bool get hasPendingInvitation => _pendingInvitation != null;

  void restoreInvitation(String code) {
    if (RegExp(r'^[0-9a-f]{64}$').hasMatch(code)) {
      _pendingInvitation ??= invitationRoute(code);
    }
  }

  String? redirect({
    required Uri uri,
    required bool authenticated,
    required bool publicRoute,
    required bool needsWelcome,
  }) {
    if (!authenticated && !publicRoute) {
      if (uri.path == '/invite') {
        final code = trainerInvitationCode(uri.toString());
        _pendingInvitation = code == null ? '/invite' : invitationRoute(code);
      }
      return '/';
    }
    if (authenticated && publicRoute) {
      final invitation = _pendingInvitation;
      _pendingInvitation = null;
      return invitation ?? (needsWelcome ? '/welcome' : '/home');
    }
    if (authenticated && uri.path == '/home' && needsWelcome) {
      return '/welcome';
    }
    return null;
  }
}

String invitationRoute(String code) =>
    Uri(path: '/invite', fragment: code).toString();

/// Admite el código actual y enlaces de invitación, sin abrir URLs externas.
String? trainerInvitationCode(String input) {
  final value = input.trim();
  final codePattern = RegExp(r'^[0-9a-f]{64}$');
  if (codePattern.hasMatch(value)) return value;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      (uri.hasScheme && uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }
  // Flutter web puede transportar la ruta dentro del fragmento de la URL.
  final String fragment;
  try {
    fragment = Uri.decodeComponent(uri.fragment);
  } on FormatException {
    return null;
  }
  final route = fragment.startsWith('/invite') ? Uri.tryParse(fragment) : uri;
  if (route?.path != '/invite') return null;
  final String? code;
  try {
    code = route!.fragment.isNotEmpty
        ? Uri.decodeComponent(route.fragment)
        : route.queryParameters['code'];
  } on FormatException {
    return null;
  }
  return code != null && codePattern.hasMatch(code) ? code : null;
}

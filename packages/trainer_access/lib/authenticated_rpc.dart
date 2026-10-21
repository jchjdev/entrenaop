import 'package:supabase_flutter/supabase_flutter.dart';

/// Envía la operación con la sesión que pertenece a [expectedUserId].
///
/// La comprobación de identidad por sí sola no fija el token: el cliente HTTP
/// de Supabase consulta Auth de forma asíncrona. La cabecera explícita impide
/// que ese intervalo adjunte credenciales de otra cuenta. Un nuevo intento
/// captura la sesión vigente y vuelve a comprobar su identidad.
/// El servidor sigue validando el token, MFA, acceso y permisos del recurso.
///
/// Un cambio de cuenta antes de recibir respuesta produce [StateError], también
/// si la petición falló. No asegura que una escritura no haya llegado a servidor:
/// el consumidor debe conservar su operación idempotente para confirmarla.
Future<dynamic> authenticatedTrainerRpc(
  SupabaseClient client,
  String expectedUserId,
  String name, {
  Map<String, dynamic>? params,
}) async {
  Session identity() {
    final current = client.auth.currentSession;
    if (expectedUserId.isEmpty ||
        current == null ||
        current.user.id != expectedUserId ||
        current.user.isAnonymous ||
        current.accessToken.trim().isEmpty) {
      throw StateError('La cuenta ha cambiado o no tiene una sesión válida.');
    }
    return current;
  }

  var session = identity();
  if (session.isExpired) {
    try {
      await client.auth.getSession();
    } finally {
      identity();
    }
    session = identity();
    if (session.isExpired) {
      throw StateError('La sesión necesita renovarse antes de continuar.');
    }
  }
  // Se captura y fija sin ningún await entre la lectura de sesión y el builder.
  final bearer = 'Bearer ${session.accessToken}';
  var request = client.rpc(name, params: params);
  // Las cabeceras del builder distinguen mayúsculas; HTTP no. Se sobrescribe
  // cada variante heredada en esta petición sin mutar las cabeceras globales.
  final authorizationKeys = {
    ...client.rest.headers.keys.where(
      (key) => key.toLowerCase() == 'authorization',
    ),
    'Authorization',
  };
  for (final key in authorizationKeys) {
    request = request.setHeader(key, bearer);
  }
  try {
    return await request;
  } finally {
    identity();
  }
}

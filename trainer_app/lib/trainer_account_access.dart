import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';

abstract class TrainerRecoveryStore {
  String? get owner;
  Future<void> write(String? owner);
}

class MemoryTrainerRecoveryStore implements TrainerRecoveryStore {
  String? _owner;
  @override
  String? get owner => _owner;
  @override
  Future<void> write(String? owner) async {
    _owner = owner;
  }
}

class PreferencesTrainerRecoveryStore implements TrainerRecoveryStore {
  PreferencesTrainerRecoveryStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'trainer_recovery_owner_v1';
  @override
  String? get owner => preferences.getString(key);
  @override
  Future<void> write(String? owner) async {
    if (owner == null) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, owner);
    }
  }
}

class TrainerAccountStatus {
  const TrainerAccountStatus({
    required this.professionalAccount,
    required this.enabled,
  });
  factory TrainerAccountStatus.fromJson(Map<String, dynamic> json) =>
      TrainerAccountStatus(
        professionalAccount: json['professional_account'] == true,
        enabled: json['enabled'] == true,
      );
  final bool professionalAccount, enabled;
}

bool isTrainerAuthCallback(Uri uri) {
  final parameters = {...uri.queryParameters};
  if (!uri.fragment.startsWith('/')) {
    try {
      parameters.addAll(Uri.splitQueryString(uri.fragment));
    } on FormatException {
      return true;
    }
  }
  return [
    'code',
    'access_token',
    'refresh_token',
    'error',
    'error_code',
    'error_description',
  ].any(parameters.containsKey);
}

String trainerAccountError(Object error) {
  final code = error is AuthException ? error.code : null;
  return switch (code) {
    'email_not_confirmed' => 'Confirma tu correo antes de entrar. Puedes solicitar otro correo desde aquí.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Espera un minuto antes de volver a intentarlo.',
    'weak_password' => 'Utiliza una contraseña de al menos 8 caracteres.',
    'same_password' => 'Elige otra contraseña. Si ya la cambiaste, prueba a iniciar sesión con la nueva.',
    'signup_disabled' =>
      'El registro no está disponible ahora. Inténtalo más tarde.',
    'user_already_exists' || 'email_exists' =>
      'Si ya tienes cuenta, inicia sesión o recupera tu contraseña.',
    'otp_expired' || 'flow_state_not_found' || 'bad_code_verifier' => 'El enlace ha caducado o no pertenece a este navegador. Solicita uno nuevo aquí.',
    _ => 'No se ha podido completar la solicitud. Revisa los datos y la conexión e inténtalo de nuevo.',
  };
}

abstract class TrainerAccountAccess {
  String? get recoveryOwner;
  String? get email;
  bool get recovering;
  bool get linkFailed;
  Future<void> register(String name, String email, String password);
  Future<void> resend(String email);
  Future<void> recover(String email);
  Future<TrainerAccountStatus> status();
  Future<bool> recoveryNeedsMfa();
  Future<void> updatePassword(String password);
  Future<void> finishRecovery();
  Future<void> rememberRecovery(String owner);
  Future<void> clearRecovery();
}

class SupabaseTrainerAccountAccess implements TrainerAccountAccess {
  SupabaseTrainerAccountAccess(
    this.client, {
    required this.url,
    required this.publishableKey,
    required this.returnUrl,
    required this.store,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null,
       _owner = store.owner;
  final SupabaseClient client;
  final String url, publishableKey, returnUrl;
  final TrainerRecoveryStore store;
  final http.Client _http;
  final bool _ownsHttp;
  String? _owner;
  bool _linkFailed = false;
  @override
  String? get recoveryOwner => _owner;
  @override
  String? get email => client.auth.currentUser?.email;
  @override
  bool get linkFailed => _linkFailed;
  @override
  bool get recovering =>
      _owner != null && client.auth.currentUser?.id == _owner;
  void dispose() {
    if (_ownsHttp) _http.close();
  }

  @override
  Future<void> rememberRecovery(String owner) async {
    _owner = owner;
    await store.write(owner);
  }

  @override
  Future<void> clearRecovery() async {
    _owner = null;
    await store.write(null);
  }

  Future<void> initializeCallback(
    Uri uri, {
    required VoidCallback cleanUrl,
  }) async {
    if (isTrainerAuthCallback(uri)) {
      try {
        final result = await client.auth.getSessionFromUrl(uri);
        if (['recovery', 'passwordRecovery'].contains(result.redirectType)) {
          await rememberRecovery(result.session.user.id);
        } else {
          await clearRecovery();
        }
      } catch (_) {
        await clearRecovery();
        _linkFailed = true;
      } finally {
        cleanUrl();
      }
    }
    if (_owner != null && client.auth.currentUser?.id != _owner) {
      await clearRecovery();
    }
  }

  @override
  Future<void> register(String name, String email, String password) async {
    if (name.trim().isEmpty || password.length < 8) {
      throw const FormatException();
    }
    // Solo el nombre es metadata editable; nunca derechos profesionales ni Pro.
    await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': name.trim()},
      emailRedirectTo: returnUrl,
    );
  }

  @override
  Future<void> resend(String email) => client.auth.resend(
    type: OtpType.signup,
    email: email.trim(),
    emailRedirectTo: returnUrl,
  );
  @override
  Future<void> recover(String email) =>
      client.auth.resetPasswordForEmail(email.trim(), redirectTo: returnUrl);
  @override
  Future<TrainerAccountStatus> status() async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw StateError('Sesión no disponible');
    return TrainerAccountStatus.fromJson(
      Map<String, dynamic>.from(
        await authenticatedTrainerRpc(
          client,
          owner,
          'get_my_trainer_account_status',
          params: {'p_expected_owner': owner},
        ) as Map,
      ),
    );
  }

  Session _recoverySession() {
    final session = client.auth.currentSession;
    if (session == null ||
        session.user.isAnonymous ||
        session.user.id != _owner ||
        session.isExpired) {
      throw StateError('El enlace ya no permite modificar esta cuenta.');
    }
    return session;
  }

  @override
  Future<bool> recoveryNeedsMfa() async {
    final before = _recoverySession();
    // listFactors renueva el JWT y provocaría otra redirección desde Auth.
    // getUser comprueba factores vigentes sin crear un bucle de renovaciones.
    final user = (await client.auth.getUser(before.accessToken)).user;
    if (client.auth.currentUser?.id != before.user.id ||
        user == null ||
        user.id != before.user.id) {
      throw StateError('La cuenta ha cambiado o no se ha podido comprobar.');
    }
    return user.factors?.any(
          (factor) => factor.status == FactorStatus.verified,
        ) ??
        false;
  }

  @override
  Future<void> updatePassword(String password) async {
    if (password.length < 8) throw const FormatException();
    final session = _recoverySession();
    // JWT explícito: cambiar de cuenta mientras se envía no puede cambiar otra contraseña.
    final response = await _http
        .put(
          Uri.parse('$url/auth/v1/user'),
          headers: {
            'apikey': publishableKey,
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'password': password}),
        )
        .timeout(const Duration(seconds: 30));
    if (client.auth.currentUser?.id != session.user.id ||
        _owner != session.user.id) {
      throw StateError('La cuenta ha cambiado.');
    }
    final body = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw AuthException(
        'No se pudo cambiar la contraseña.',
        code: body is Map ? body['code'] as String? : null,
      );
    }
    if (body is! Map || body['id'] != session.user.id) {
      throw StateError('Respuesta no confirmada.');
    }
  }

  @override
  Future<void> finishRecovery() async {
    _recoverySession();
    await client.auth.signOut(scope: SignOutScope.local);
    await clearRecovery();
  }
}

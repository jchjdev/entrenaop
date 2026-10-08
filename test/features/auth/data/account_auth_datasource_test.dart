import 'dart:async';
import 'dart:convert';

import 'package:entrenaop/features/auth/domain/entities/auth_session_change.dart';

import 'package:entrenaop/core/errors/exceptions.dart';
import 'package:entrenaop/core/config/auth_redirect.dart';
import 'package:entrenaop/features/auth/data/datasources/auth_remote_datasource_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'web vuelve al mismo origen y retira código, tokens y fragmento de la URL',
    () {
      expect(
        AuthRedirect.resolve(
          isWeb: true,
          baseUri: Uri.parse('http://localhost:55234/?code=un-codigo#/home'),
          isProduction: false,
        ),
        'http://localhost:55234/',
      );
      expect(
        AuthRedirect.resolve(isWeb: false, baseUri: Uri(), isProduction: false),
        AuthRedirect.mobileCallback,
      );
      expect(
        () => AuthRedirect.resolve(
          isWeb: true,
          baseUri: Uri.parse('http://localhost:3000/'),
          isProduction: true,
        ),
        throwsStateError,
      );
      expect(
        () => AuthRedirect.resolve(
          isWeb: false,
          baseUri: Uri(),
          isProduction: false,
          configuredUrl: 'https://user:secret@example.com/callback',
        ),
        throwsStateError,
      );
      expect(
        AuthRedirect.resolve(
          isWeb: true,
          baseUri: Uri.parse('https://app.example.com/entrena/'),
          isProduction: true,
        ),
        'https://app.example.com/entrena/',
      );
    },
  );
  test(
    'solicitud y reenvío usan Auth, PKCE y la redirección configurada',
    () async {
      final fixture = await _fixture();
      await fixture.source.requestPasswordReset('persona@example.com');
      await fixture.source.resendConfirmation('persona@example.com');
      expect(fixture.requests.map((r) => r.url.path), [
        '/auth/v1/recover',
        '/auth/v1/resend',
      ]);
      for (final request in fixture.requests) {
        expect(
          request.url.queryParameters['redirect_to'],
          AuthRedirect.mobileCallback,
        );
        final body = jsonDecode(request.body) as Map;
        expect(body['email'], 'persona@example.com');
        expect(body['code_challenge'], isNotEmpty);
        expect(body['code_challenge_method'], 's256');
        expect(body.containsKey('password'), false);
      }
    },
  );
  test('canje PKCE valida recuperación, consume el verificador y evita consultar el perfil', () async {
    final fixture = await _fixture();
    final events = <AuthSessionChange>[];
    final subscription = fixture.source.watchCurrentUser().listen(events.add);
    addTearDown(subscription.cancel);
    await fixture.source.requestPasswordReset('persona@example.com');
    await fixture.client.auth.exchangeCodeForSession('fixture-code');
    await Future<void>.delayed(Duration.zero);
    expect(events.single.recoveryUserId, 'owner');
    expect(events.single.passwordUpdated, false);
    expect(
      fixture.prefs.getString(AuthRemoteDataSourceImpl.recoveryOwnerKey),
      'owner',
    );
    await expectLater(
      fixture.client.auth.exchangeCodeForSession('fixture-code'),
      throwsA(isA<AuthException>()),
    );
    expect(fixture.requests.map((r) => r.url.path), [
      '/auth/v1/recover',
      '/auth/v1/token',
    ]);
  });
  test(
    'rechaza el cambio sin sesión o con marcador perteneciente a otro usuario',
    () async {
      final fixture = await _fixture();
      await expectLater(
        fixture.source.updateRecoveredPassword('nueva-clave'),
        throwsA(isA<AuthLinkException>()),
      );
      await fixture.client.auth.setInitialSession(
        jsonEncode(_session('owner')),
      );
      await fixture.prefs.setString(
        AuthRemoteDataSourceImpl.recoveryOwnerKey,
        'other',
      );
      await expectLater(
        fixture.source.updateRecoveredPassword('nueva-clave'),
        throwsA(isA<AuthLinkException>()),
      );
      expect(fixture.requests, isEmpty);
    },
  );
  test('marcador de recuperación se conserva con sesión vigente y se limpia al salir localmente', () async {
    final fixture = await _fixture();
    await fixture.prefs.setString(
      AuthRemoteDataSourceImpl.recoveryOwnerKey,
      'owner',
    );
    await fixture.prefs.setBool(
      AuthRemoteDataSourceImpl.recoveryUpdatedKey,
      true,
    );
    await fixture.client.auth.setInitialSession(jsonEncode(_session('owner')));
    final change = await fixture.source.watchCurrentUser().first;
    expect(change.recoveryUserId, 'owner');
    expect(change.passwordUpdated, true);
    expect(fixture.requests, isEmpty);
    await fixture.source.finishPasswordRecovery();
    expect(
      fixture.prefs.containsKey(AuthRemoteDataSourceImpl.recoveryOwnerKey),
      false,
    );
    expect(fixture.requests.single.url.queryParameters['scope'], 'local');
  });
  test(
    'el cambio de cuenta no hereda el marcador de recuperación anterior',
    () async {
      final fixture = await _fixture();
      await fixture.prefs.setString(
        AuthRemoteDataSourceImpl.recoveryOwnerKey,
        'other',
      );
      await fixture.client.auth.setInitialSession(
        jsonEncode(_session('owner')),
      );
      final change = await fixture.source.watchCurrentUser().first;
      expect(change.recoveryUserId, isNull);
      expect(change.user!.id, 'owner');
      expect(
        fixture.prefs.containsKey(AuthRemoteDataSourceImpl.recoveryOwnerKey),
        false,
      );
    },
  );
  test(
    'Supabase rechaza una sesión inválida aunque el marcador local coincida',
    () async {
      final fixture = await _fixture(failUpdate: true);
      await fixture.prefs.setString(
        AuthRemoteDataSourceImpl.recoveryOwnerKey,
        'owner',
      );
      await fixture.client.auth.setInitialSession(
        jsonEncode(_session('owner')),
      );
      await expectLater(
        fixture.source.updateRecoveredPassword('nueva-clave'),
        throwsA(isA<AuthLinkException>()),
      );
      expect(
        fixture.prefs.getBool(AuthRemoteDataSourceImpl.recoveryUpdatedKey),
        isNot(true),
      );
      expect(fixture.requests.single.method, 'PUT');
    },
  );
  test(
    'una respuesta pendiente no confirma el recorrido de otra cuenta',
    () async {
      final response = Completer<http.Response>();
      final fixture = await _fixture(pendingUpdate: response);
      await fixture.prefs.setString(
        AuthRemoteDataSourceImpl.recoveryOwnerKey,
        'owner',
      );
      await fixture.client.auth.setInitialSession(
        jsonEncode(_session('owner')),
      );
      final saving = fixture.source.updateRecoveredPassword(
        'nueva-clave-segura',
      );
      await Future<void>.delayed(Duration.zero);
      expect(fixture.requests.single.method, 'PUT');
      await fixture.prefs.setString(
        AuthRemoteDataSourceImpl.recoveryOwnerKey,
        'other',
      );
      await fixture.prefs.setBool(
        AuthRemoteDataSourceImpl.recoveryUpdatedKey,
        false,
      );
      response.complete(http.Response(jsonEncode(_user('owner')), 200));
      await saving;
      expect(
        fixture.prefs.getBool(AuthRemoteDataSourceImpl.recoveryUpdatedKey),
        false,
      );
    },
  );
  test('guardado envía la contraseña solo a Auth y persiste únicamente el estado del recorrido', () async {
    final fixture = await _fixture();
    await fixture.prefs.setString(
      AuthRemoteDataSourceImpl.recoveryOwnerKey,
      'owner',
    );
    await fixture.client.auth.setInitialSession(jsonEncode(_session('owner')));
    await fixture.source.updateRecoveredPassword('nueva-clave-segura');
    final request = fixture.requests.single;
    expect(request.url.path, '/auth/v1/user');
    expect(jsonDecode(request.body)['password'], 'nueva-clave-segura');
    expect(
      fixture.prefs.getBool(AuthRemoteDataSourceImpl.recoveryUpdatedKey),
      true,
    );
    expect(fixture.prefs.getKeys(), {
      AuthRemoteDataSourceImpl.recoveryOwnerKey,
      AuthRemoteDataSourceImpl.recoveryUpdatedKey,
    });
  });
}

Map<String, Object?> _user(String id) => {
  'id': id,
  'email': 'persona@example.com',
  'aud': 'authenticated',
  'role': 'authenticated',
  'app_metadata': {},
  'user_metadata': {},
  'created_at': '2026-10-08T00:00:00Z',
};
Map<String, Object?> _session(String id) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'exp':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      )
      .replaceAll('=', '');
  return {
    'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
    'refresh_token': 'fixture-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': _user(id),
  };
}

Future<
  ({
    AuthRemoteDataSourceImpl source,
    SupabaseClient client,
    SharedPreferences prefs,
    List<http.Request> requests,
  })
>
_fixture({
  bool failUpdate = false,
  Completer<http.Response>? pendingUpdate,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final requests = <http.Request>[];
  final client = SupabaseClient(
    'https://auth-fixture.example.com',
    'fixture-key',
    authOptions: AuthClientOptions(
      autoRefreshToken: false,
      pkceAsyncStorage: _MemoryStorage(),
    ),
    httpClient: MockClient((request) async {
      requests.add(request);
      if (request.method == 'PUT' && pendingUpdate != null) {
        return pendingUpdate.future;
      }
      if (request.url.path == '/auth/v1/token') {
        return http.Response(jsonEncode(_session('owner')), 200);
      }
      if (request.method == 'PUT' && failUpdate) {
        return http.Response(
          jsonEncode({
            'code': 'session_not_found',
            'error_code': 'session_not_found',
            'message': 'Invalid session',
          }),
          401,
        );
      }
      if (request.url.path == '/rest/v1/profiles') {
        return http.Response(
          jsonEncode({
            'id': 'owner',
            'role': 'user',
            'created_at': '2026-10-08T00:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      if (request.url.path == '/auth/v1/user') {
        return http.Response(jsonEncode(_user('owner')), 200);
      }
      return http.Response('{}', 200);
    }),
  );
  addTearDown(client.dispose);
  return (
    source: AuthRemoteDataSourceImpl(
      supabaseClient: client,
      preferences: prefs,
      redirectUrl: AuthRedirect.mobileCallback,
    ),
    client: client,
    prefs: prefs,
    requests: requests,
  );
}

class _MemoryStorage implements GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

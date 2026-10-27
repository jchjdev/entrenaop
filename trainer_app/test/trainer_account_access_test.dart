import 'dart:async';
import 'dart:convert';

import 'package:entrenaop_trainer/trainer_account_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const accountOwner = '10000000-0000-4000-8000-000000000001';
Map<String, dynamic> accountUser(String owner) => {
  'id': owner,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'owner@example.invalid',
  'created_at': '2026-10-27T00:00:00Z',
  'app_metadata': {},
  'user_metadata': {},
  'is_anonymous': false,
  'factors': [
    {
      'id': 'factor',
      'status': 'verified',
      'factor_type': 'totp',
      'created_at': '2026-10-27T00:00:00Z',
      'updated_at': '2026-10-27T00:00:00Z',
    },
  ],
};
Map<String, dynamic> accountSession(String owner) {
  final claims = base64Url
      .encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})))
      .replaceAll('=', '');
  return {
    'access_token': 'eyJhbGciOiJIUzI1NiJ9.$claims.fixture',
    'refresh_token': 'refresh',
    'token_type': 'bearer',
    'user': accountUser(owner),
  };
}

class MemoryPkceStore extends GotrueAsyncStorage {
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

void main() {
  test(
    'cambio confirmado vuelve a login y borra el contexto de recuperación',
    () async {
      final network = MockClient(
        (request) async => request.url.path.endsWith('/logout')
            ? http.Response('', 204)
            : http.Response(jsonEncode(accountUser(accountOwner)), 200),
      );
      final client = SupabaseClient(
        'https://auth.example.invalid',
        'public',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: network,
      );
      addTearDown(client.dispose);
      await client.auth.setInitialSession(
        jsonEncode(accountSession(accountOwner)),
      );
      final store = MemoryTrainerRecoveryStore();
      final accounts = SupabaseTrainerAccountAccess(
        client,
        url: 'https://auth.example.invalid',
        publishableKey: 'public',
        returnUrl: 'https://trainer.entrenaop.es/',
        store: store,
        httpClient: network,
      );
      await accounts.rememberRecovery(accountOwner);
      await accounts.updatePassword('new-password');
      await accounts.finishRecovery();
      expect(client.auth.currentSession, isNull);
      expect(store.owner, isNull);
      expect(accounts.recovering, false);
    },
  );

  test('consultar MFA de recuperación no renueva el token ni genera un bucle de Auth', () async {
    final requests = <http.Request>[];
    final network = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(accountUser(accountOwner)), 200);
    });
    final client = SupabaseClient(
      'https://auth.example.invalid',
      'public',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: network,
    );
    addTearDown(client.dispose);
    await client.auth.setInitialSession(
      jsonEncode(accountSession(accountOwner)),
    );
    final accounts = SupabaseTrainerAccountAccess(
      client,
      url: 'https://auth.example.invalid',
      publishableKey: 'public',
      returnUrl: 'https://trainer.entrenaop.es/',
      store: MemoryTrainerRecoveryStore(),
      httpClient: network,
    );
    await accounts.rememberRecovery(accountOwner);
    expect(await accounts.recoveryNeedsMfa(), true);
    expect(requests.map((r) => r.url.pathSegments.last), ['user']);
  });

  test('el retorno PKCE conserva el tipo recovery y consume el verificador del navegador', () async {
    final requests = <http.Request>[];
    final pkce = MemoryPkceStore();
    final network = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode(
          request.url.path.endsWith('/token')
              ? accountSession(accountOwner)
              : {},
        ),
        200,
      );
    });
    final client = SupabaseClient(
      'https://auth.example.invalid',
      'public',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: pkce,
      ),
      httpClient: network,
    );
    addTearDown(client.dispose);
    final accounts = SupabaseTrainerAccountAccess(
      client,
      url: 'https://auth.example.invalid',
      publishableKey: 'public',
      returnUrl: 'https://trainer.entrenaop.es/',
      store: MemoryTrainerRecoveryStore(),
      httpClient: network,
    );
    await accounts.recover('owner@example.invalid');
    expect(pkce.values, isNotEmpty);
    var cleaned = false;
    await accounts.initializeCallback(
      Uri.parse('https://trainer.entrenaop.es/?code=confirmed-code'),
      cleanUrl: () => cleaned = true,
    );
    expect(accounts.recovering, true);
    expect(accounts.recoveryOwner, accountOwner);
    expect(cleaned, true);
    expect(pkce.values, isEmpty);
    final exchange = requests.last;
    expect(exchange.url.queryParameters['grant_type'], 'pkce');
    final body = jsonDecode(exchange.body) as Map;
    expect(body['auth_code'], 'confirmed-code');
    expect(body['code_verifier'], isNotEmpty);
  });

  test('detecta callbacks, nunca confunde las rutas del panel ni una query de recuperación', () {
    expect(
      isTrainerAuthCallback(
        Uri.parse('https://trainer.entrenaop.es/#/register'),
      ),
      false,
    );
    expect(
      isTrainerAuthCallback(
        Uri.parse('https://trainer.entrenaop.es/?account=recovery'),
      ),
      false,
    );
    expect(
      isTrainerAuthCallback(
        Uri.parse('https://trainer.entrenaop.es/?code=private-code'),
      ),
      true,
    );
    expect(
      isTrainerAuthCallback(
        Uri.parse('https://trainer.entrenaop.es/#access_token=private'),
      ),
      true,
    );
  });
  test('registro solo transmite nombre y vuelve al origen web; recuperar y reenviar no conceden derechos', () async {
    final requests = <http.Request>[];
    final network = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode(
          request.url.path.endsWith('/signup') ? accountUser(accountOwner) : {},
        ),
        200,
      );
    });
    final client = SupabaseClient(
      'https://auth.example.invalid',
      'public',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryPkceStore(),
      ),
      httpClient: network,
    );
    final accounts = SupabaseTrainerAccountAccess(
      client,
      url: 'https://auth.example.invalid',
      publishableKey: 'public',
      returnUrl: 'https://trainer.entrenaop.es/',
      store: MemoryTrainerRecoveryStore(),
      httpClient: network,
    );
    addTearDown(client.dispose);
    await accounts.register(
      ' Ana Soria ',
      ' ana@example.invalid ',
      'password-strong',
    );
    await accounts.recover(' ana@example.invalid ');
    await accounts.resend(' ana@example.invalid ');
    expect(requests.map((r) => r.url.pathSegments.last), [
      'signup',
      'recover',
      'resend',
    ]);
    final signup = jsonDecode(requests.first.body) as Map;
    expect(signup['data'], {'full_name': 'Ana Soria'});
    expect(signup['email'], 'ana@example.invalid');
    for (final request in requests) {
      expect(
        request.url.queryParameters['redirect_to'],
        'https://trainer.entrenaop.es/',
      );
    }
  });
  test('recuperación se liga a la sesión validada y limpia el callback aunque falle', () async {
    final network = MockClient(
      (r) async => http.Response(jsonEncode(accountUser(accountOwner)), 200),
    );
    final client = SupabaseClient(
      'https://auth.example.invalid',
      'public',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryPkceStore(),
      ),
      httpClient: network,
    );
    addTearDown(client.dispose);
    final store = MemoryTrainerRecoveryStore();
    final accounts = SupabaseTrainerAccountAccess(
      client,
      url: 'https://auth.example.invalid',
      publishableKey: 'public',
      returnUrl: 'https://trainer.entrenaop.es/',
      store: store,
      httpClient: network,
    );
    final session = accountSession(accountOwner);
    var cleared = 0;
    final uri = Uri.parse(
      'https://trainer.entrenaop.es/#access_token=${session['access_token']}&refresh_token=refresh&token_type=bearer&expires_in=3600&type=recovery',
    );
    await accounts.initializeCallback(uri, cleanUrl: () => cleared++);
    expect(accounts.recovering, true);
    expect(store.owner, accountOwner);
    expect(cleared, 1);
    final restored = SupabaseTrainerAccountAccess(
      client,
      url: 'https://auth.example.invalid',
      publishableKey: 'public',
      returnUrl: 'https://trainer.entrenaop.es/',
      store: store,
      httpClient: network,
    );
    await restored.initializeCallback(
      Uri.parse('https://trainer.entrenaop.es/#/home'),
      cleanUrl: () => fail('No callback'),
    );
    expect(restored.recovering, true);
    await restored.initializeCallback(
      Uri.parse('https://trainer.entrenaop.es/?error=expired'),
      cleanUrl: () => cleared++,
    );
    expect(restored.linkFailed, true);
    expect(restored.recovering, false);
    expect(store.owner, isNull);
    expect(cleared, 2);
  });
  test('contraseña usa JWT capturado y no cambia la cuenta que aparece durante el envío', () async {
    final started = Completer<void>(), release = Completer<void>();
    late http.Request captured;
    final network = MockClient((r) async {
      captured = r;
      started.complete();
      await release.future;
      return http.Response(jsonEncode(accountUser(accountOwner)), 200);
    });
    final client = SupabaseClient(
      'https://auth.example.invalid',
      'public',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryPkceStore(),
      ),
    );
    addTearDown(client.dispose);
    await client.auth.setInitialSession(
      jsonEncode(accountSession(accountOwner)),
    );
    final token = client.auth.currentSession!.accessToken;
    final accounts = SupabaseTrainerAccountAccess(
      client,
      url: 'https://auth.example.invalid',
      publishableKey: 'public',
      returnUrl: 'https://trainer.entrenaop.es/',
      store: MemoryTrainerRecoveryStore(),
      httpClient: network,
    );
    await expectLater(
      accounts.updatePassword('new-password'),
      throwsStateError,
    );
    await accounts.rememberRecovery(accountOwner);
    final change = accounts.updatePassword('new-password');
    final failed = expectLater(change, throwsStateError);
    await started.future;
    await client.auth.setInitialSession(
      jsonEncode(accountSession('10000000-0000-4000-8000-000000000002')),
    );
    release.complete();
    await failed;
    expect(captured.headers['Authorization'], 'Bearer $token');
    expect(jsonDecode(captured.body), {'password': 'new-password'});
  });
  test('el almacenamiento de recuperación guarda solo identidad y permite borrarla', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PreferencesTrainerRecoveryStore(prefs);
    await store.write(accountOwner);
    expect(store.owner, accountOwner);
    expect(prefs.getKeys(), {PreferencesTrainerRecoveryStore.key});
    await store.write(null);
    expect(store.owner, isNull);
  });
  test(
    'los errores de acceso no imprimen respuestas privadas del servidor',
    () {
      expect(
        trainerAccountError(const AuthException('private-secret')),
        isNot(contains('private-secret')),
      );
    },
  );
}

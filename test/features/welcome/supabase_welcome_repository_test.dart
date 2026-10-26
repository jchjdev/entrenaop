import 'dart:async';
import 'dart:convert';

import 'package:entrenaop/features/welcome/data/supabase_welcome_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '10000000-0000-4000-8000-000000000001';
const _other = '10000000-0000-4000-8000-000000000002';

Map<String, dynamic> _user(String id, {bool completed = false}) => {
  'id': id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'created_at': '2026-10-26T00:00:00Z',
  'app_metadata': {},
  'user_metadata': {
    'full_name': 'Nombre conservado',
    if (completed) SupabaseWelcomeRepository.metadataKey: true,
  },
};

String _token(String id) =>
    'eyJhbGciOiJIUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode({'sub': id, 'exp': 4102444800}))).replaceAll('=', '')}.fixture';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SupabaseClient> account() async {
    final client = SupabaseClient(
      'https://welcome.example.com',
      'public-fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'access_token': _token(_owner),
            'refresh_token': 'fixture',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': _user(_owner),
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'persona@example.com',
      password: 'fixture',
    );
    return client;
  }

  test('lee la preferencia vigente aunque la sesión local conserve metadata antigua', () async {
    final client = await account();
    var reads = 0;
    final repository = SupabaseWelcomeRepository(
      client,
      authEndpoint: Uri.parse('https://welcome.example.com/auth/v1/user'),
      httpClient: MockClient((request) async {
        reads++;
        expect(request.headers['Authorization'], 'Bearer ${_token(_owner)}');
        return http.Response(jsonEncode(_user(_owner, completed: true)), 200);
      }),
    );
    addTearDown(repository.dispose);
    expect(
      client.auth.currentUser!.userMetadata![SupabaseWelcomeRepository
          .metadataKey],
      isNull,
    );
    expect(await repository.isCompleted(_owner), isTrue);
    expect(await repository.isCompleted(_owner), isTrue);
    expect(reads, 1);
  });

  test('guarda solo la preferencia y permite omitir únicamente en esta sesión si falla', () async {
    final client = await account();
    var fail = true;
    final repository = SupabaseWelcomeRepository(
      client,
      authEndpoint: Uri.parse('https://welcome.example.com/auth/v1/user'),
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(jsonDecode(request.body), {
          'data': {SupabaseWelcomeRepository.metadataKey: true},
        });
        return fail
            ? http.Response('{}', 503)
            : http.Response(jsonEncode(_user(_owner, completed: true)), 200);
      }),
    );
    addTearDown(repository.dispose);
    await expectLater(repository.complete(_owner), throwsStateError);
    fail = false;
    await repository.complete(_owner);
    expect(await repository.isCompleted(_owner), isTrue);
    expect(
      client.auth.currentUser!.userMetadata!['full_name'],
      'Nombre conservado',
    );
    await expectLater(repository.complete(_other), throwsStateError);
  });

  test('una escritura tardía no sustituye la sesión de otra cuenta ni completa su bienvenida', () async {
    final client = await account();
    final pending = Completer<http.Response>(), sent = Completer<void>();
    final repository = SupabaseWelcomeRepository(
      client,
      authEndpoint: Uri.parse('https://welcome.example.com/auth/v1/user'),
      httpClient: MockClient((request) {
        expect(request.headers['Authorization'], 'Bearer ${_token(_owner)}');
        sent.complete();
        return pending.future;
      }),
    );
    addTearDown(repository.dispose);
    final write = repository.complete(_owner);
    final rejected = expectLater(write, throwsStateError);
    await sent.future;
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': _token(_other),
        'refresh_token': 'other-fixture',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': _user(_other),
      }),
    );
    pending.complete(
      http.Response(jsonEncode(_user(_owner, completed: true)), 200),
    );
    await rejected;
    expect(client.auth.currentUser!.id, _other);
    expect(client.auth.currentSession!.accessToken, _token(_other));
    expect(
      client.auth.currentUser!.userMetadata![SupabaseWelcomeRepository
          .metadataKey],
      isNull,
    );
  });

  test('una omisión temporal no impide guardar definitivamente al volver desde Perfil', () async {
    final client = await account();
    var writes = 0;
    final repository = SupabaseWelcomeRepository(
      client,
      authEndpoint: Uri.parse('https://welcome.example.com/auth/v1/user'),
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        writes++;
        return http.Response(jsonEncode(_user(_owner, completed: true)), 200);
      }),
    );
    addTearDown(repository.dispose);
    repository.skipForSession(_owner);
    expect(await repository.isCompleted(_owner), isTrue);
    await repository.complete(_owner);
    expect(writes, 1);
    expect(await repository.isCompleted(_owner), isTrue);
  });

  test(
    'continuar por ahora no escribe en servidor y no se traslada a otra cuenta',
    () async {
      final client = await account();
      final repository = SupabaseWelcomeRepository(
        client,
        authEndpoint: Uri.parse('https://welcome.example.com/auth/v1/user'),
        httpClient: MockClient(
          (_) => throw StateError('No debe acceder a red'),
        ),
      );
      addTearDown(repository.dispose);
      repository.skipForSession(_owner);
      expect(await repository.isCompleted(_owner), isTrue);
      expect(() => repository.skipForSession(_other), throwsStateError);
    },
  );
}

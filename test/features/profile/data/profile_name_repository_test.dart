import 'dart:async';
import 'dart:convert';

import 'package:entrenaop/features/profile/data/profile_name_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const owner = '10000000-0000-4000-8000-000000000001';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('fija propietario/token y rechaza respuesta tras cambio de cuenta', () async {
    final pending = Completer<http.Response>(), sent = Completer<void>();
    final requests = <http.Request>[];
    late String token;
    final client = SupabaseClient(
      'https://profile-fixture.example.com',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          token =
              'eyJhbGciOiJIUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800}))).replaceAll('=', '')}.fixture';
          return http.Response(
            jsonEncode({
              'access_token': token,
              'refresh_token': 'fixture',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': owner,
                'aud': 'authenticated',
                'role': 'authenticated',
                'created_at': '2026-10-20T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/rpc/update_my_profile_name')) {
          requests.add(request);
          sent.complete();
          return pending.future;
        }
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'javier@example.com',
      password: 'fixture',
    );
    final repository = ProfileNameRepository(client);
    await expectLater(repository.save(owner, '  '), throwsFormatException);
    await expectLater(repository.save('other', 'Javier'), throwsStateError);
    expect(requests, isEmpty);
    final write = repository.save(owner, '  Javier   Charlez  ');
    final rejected = expectLater(write, throwsStateError);
    await sent.future;
    expect(jsonDecode(requests.single.body), {
      'p_expected_owner': owner,
      'p_name': 'Javier Charlez',
    });
    expect(
      requests.single.headers['Authorization'] ??
          requests.single.headers['authorization'],
      'Bearer $token',
    );
    await client.auth.signOut();
    pending.complete(
      http.Response(
        jsonEncode('Javier Charlez'),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await rejected;
  });
}

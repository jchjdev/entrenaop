import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:entrenaop/features/device_activity_results/domain/activity_result.dart';
import 'package:entrenaop/features/device_activity_results/data/supabase_activity_result_repository.dart';

void main() {
  test(
    'descarta carreras de una petición en vuelo tras cambiar de cuenta',
    () async {
      const owner = '10000000-0000-4000-8000-000000000001';
      final pending = Completer<http.Response>(), started = Completer<void>();
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) {
          if (request.url.path.contains('/functions/')) {
            expect(jsonDecode(request.body)['expected_user_id'], owner);
            expect(jsonDecode(request.body)['activity_schema_version'], 2);
            started.complete();
            return pending.future;
          }
          return Future.value(http.Response('{}', 200));
        }),
      );
      addTearDown(client.dispose);
      String savedSession(String user) {
        final payload = base64Url.encode(
          utf8.encode(
            jsonEncode({
              'sub': user,
              'exp':
                  DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
              'session_id': '20000000-0000-4000-8000-000000000001',
            }),
          ),
        );
        return jsonEncode({
          'access_token': 'e30.$payload.fixture',
          'refresh_token': 'fixture',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': user,
            'app_metadata': {},
            'user_metadata': {},
            'aud': 'authenticated',
            'created_at': '2026-10-22T00:00:00Z',
          },
        });
      }

      await client.auth.recoverSession(savedSession(owner));
      final repository = SupabaseActivityResultRepository(client, owner);
      final result = repository.load();
      final assertion = expectLater(
        result,
        throwsA(
          isA<ActivityResultException>().having(
            (e) => e.code,
            'code',
            'account_changed',
          ),
        ),
      );
      await started.future;
      await client.auth.recoverSession(
        savedSession('10000000-0000-4000-8000-000000000002'),
      );
      pending.complete(
        http.Response(
          '{"activities":[],"candidates":[],"problems":[]}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await assertion;
    },
  );
}

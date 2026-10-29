import 'dart:convert';

import 'package:entrenaop_admin/features/exercises/data/admin_media_cleanup_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_exercise_preferences_repository_test.dart' show clientFor, owner;

void main() {
  test(
    'ADMIN fija cuenta/scope oficial y conserva UUID ante recibo incierto',
    () async {
      final calls = <http.Request>[];
      var invalid = true;
      final client = clientFor((request) async {
        calls.add(request);
        final body = jsonDecode(request.body) as Map;
        return http.Response(
          jsonEncode({
            'items': [],
            'summary': {
              'pending': 1,
              'deleted': 0,
              'protected': 0,
              'freed_images': 0,
              'freed_bytes': 0,
            },
            'receipt': {
              'expected_user_id': owner,
              'operation_id': invalid ? 'other' : body['operation_id'],
              'action': body['action'],
              'scope': 'official',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'fixture@example.invalid',
        password: 'fixture',
      );
      final repository = SupabaseAdminMediaCleanupRepository(client, owner);
      await expectLater(repository.sweep('operation'), throwsStateError);
      invalid = false;
      await repository.sweep('operation');
      expect(calls.first.body, calls.last.body);
      for (final call in calls) {
        expect(
          call.headers['authorization'],
          'Bearer ${client.auth.currentSession!.accessToken}',
        );
        final body = jsonDecode(call.body) as Map;
        expect(body['scope'], 'official');
        expect(body['expected_user_id'], owner);
      }
    },
  );

  for (final status in [403, 503]) {
    test(
      'ADMIN distingue rechazo definitivo $status de respuesta incierta',
      () async {
        final client = clientFor(
          (request) async => http.Response(
            jsonEncode({'error': 'internal details'}),
            status,
            headers: {'content-type': 'application/json'},
          ),
        );
        addTearDown(client.dispose);
        await client.auth.signInWithPassword(
          email: 'fixture@example.invalid',
          password: 'fixture',
        );
        await expectLater(
          SupabaseAdminMediaCleanupRepository(client, owner).sweep('operation'),
          status == 403
              ? throwsA(isA<FormatException>())
              : throwsA(isA<FunctionException>()),
        );
      },
    );
  }
}

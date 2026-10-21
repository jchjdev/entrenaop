import 'dart:async';
import 'dart:convert';

import 'package:entrenaop_admin/features/exercises/data/admin_exercise_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const owner = '10000000-0000-4000-8000-000000000001';
const exercise = '20000000-0000-4000-8000-000000000001';
const entry = {
  'exercise_id': exercise,
  'favorite': true,
  'favorite_revision': 1,
  'last_selected_at': '2026-10-21T12:00:00Z',
};

http.Response response(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
);

SupabaseClient clientFor(Future<http.Response> Function(http.Request) handle) =>
    SupabaseClient(
      'https://fixture.invalid',
      'fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/logout') return response({});
        if (request.url.path == '/auth/v1/token') {
          final payload = base64Url
              .encode(
                utf8.encode(jsonEncode({'sub': owner, 'exp': 4102444800})),
              )
              .replaceAll('=', '');
          return response({
            'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
            'refresh_token': 'fixture',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': owner,
              'aud': 'authenticated',
              'role': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-10-21T00:00:00Z',
            },
          });
        }
        final result = await handle(request);
        return http.Response.bytes(
          result.bodyBytes,
          result.statusCode,
          headers: result.headers,
          request: request,
        );
      }),
    );

void main() {
  test('contexto ADMIN cerrado y recibos con UUID sin identidad elegible por el cliente', () async {
    final calls = <Map<String, dynamic>>[];
    final client = clientFor((request) async {
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      calls.add(body);
      expect(body['p_context'], 'admin_official');
      expect(body.keys, isNot(contains('p_user_id')));
      return response(
        request.url.path.endsWith('get_editor_exercise_preferences')
            ? {
                'entries': [entry],
                'recent_limit': 20,
                'favorite_limit': 500,
              }
            : entry,
      );
    });
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'fixture@example.invalid',
      password: 'fixture',
    );
    final repository = SupabaseAdminExercisePreferencesRepository(
      client,
      owner,
    );
    final snapshot = await repository.read();
    expect(snapshot.entries.single.exerciseId, exercise);
    final operation = repository.newOperationId();
    expect(
      operation,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    await repository.setFavorite(
      exercise,
      true,
      expectedRevision: 1,
      operationId: operation,
    );
    await repository.recordSelection(
      exercise,
      operationId: repository.newOperationId(),
    );
    expect(calls[1]['p_operation_id'], operation);
    expect(calls[1]['p_expected_revision'], 1);
    expect(calls[2]['p_exercise_id'], exercise);
  });

  test('salir durante lectura rechaza la respuesta anterior y las siguientes acciones', () async {
    final delayed = Completer<http.Response>();
    final started = Completer<void>();
    var requests = 0;
    final client = clientFor((request) async {
      requests++;
      started.complete();
      return delayed.future;
    });
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
      email: 'fixture@example.invalid',
      password: 'fixture',
    );
    final repository = SupabaseAdminExercisePreferencesRepository(
      client,
      owner,
    );
    final read = repository.read();
    final rejected = expectLater(read, throwsStateError);
    await started.future;
    await client.auth.signOut(scope: SignOutScope.local);
    delayed.complete(
      response({
        'entries': [entry],
        'recent_limit': 20,
        'favorite_limit': 500,
      }),
    );
    await rejected;
    final operation = repository.newOperationId();
    expect(
      () => repository.setFavorite(
        exercise,
        false,
        expectedRevision: 1,
        operationId: operation,
      ),
      throwsStateError,
    );
    expect(
      () => repository.recordSelection(exercise, operationId: operation),
      throwsStateError,
    );
    await expectLater(repository.read(), throwsStateError);
    expect(requests, 1);
  });
}

import 'dart:convert';

import 'package:entrenaop/features/preparation_goal/data/repositories/preparation_training_repository_impl.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final execution in ['execution-other-goal', null]) {
    test(
      'consulta solo la ejecución abierta de la cuenta, sin limitar semana o preparación: $execution',
      () async {
        final requests = <http.Request>[];
        final client = _client(requests, execution: execution);
        addTearDown(client.dispose);
        await client.auth.setInitialSession(jsonEncode(_session));
        final id = await SupabasePreparationTrainingRepository(client)
            .getInProgressExecutionId();
        expect(id, execution);
        final query = requests
            .singleWhere((r) => r.url.path == '/rest/v1/scheduled_workouts')
            .url
            .queryParameters;
        expect(query, {
          'select': 'execution_id',
          'user_id': 'eq.owner',
          'status': 'eq.in_progress',
          'order': 'scheduled_date.asc.nullslast,id.asc.nullslast',
          'limit': '1',
        });
      },
    );
  }

  test(
    'sin sesión no consulta datos; un fallo de red admite reintento',
    () async {
      final requests = <http.Request>[];
      final client = _client(requests, fail: true);
      addTearDown(client.dispose);
      final repository = SupabasePreparationTrainingRepository(client);
      await expectLater(
        repository.getInProgressExecutionId(),
        throwsA(isA<PreparationTrainingException>()),
      );
      expect(requests, isEmpty);
      await client.auth.setInitialSession(jsonEncode(_session));
      await expectLater(
        repository.getInProgressExecutionId(),
        throwsA(
          isA<PreparationTrainingException>().having(
            (e) => e.message,
            'mensaje',
            contains('Vuelve a intentarlo'),
          ),
        ),
      );
    },
  );
}

SupabaseClient _client(
  List<http.Request> requests, {
  String? execution,
  bool fail = false,
}) => SupabaseClient(
  'https://plan-fixture.example.test',
  'fixture-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    requests.add(request);
    if (fail) return http.Response('{}', 503);
    return http.Response(
      jsonEncode(
        execution == null
            ? []
            : [
                {'execution_id': execution},
              ],
      ),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }),
);

final _session = {
  'access_token':
      'eyJhbGciOiJIUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000}))).replaceAll('=', '')}.fixture',
  'refresh_token': 'fixture-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': 'owner',
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'owner@example.test',
    'app_metadata': const {},
    'user_metadata': const {},
    'created_at': '2026-10-08T00:00:00Z',
  },
};

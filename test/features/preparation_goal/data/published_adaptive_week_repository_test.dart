import 'dart:async';
import 'dart:convert';

import 'package:entrenaop/features/preparation_goal/data/repositories/published_adaptive_week_repository_impl.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/published_adaptive_week_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'lee ambas instantáneas vigentes solo con GET y acota cuenta y lunes',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) async {
        requests.add(request);
        return _response([
          {
            'decision': {
              'table': request.url.pathSegments.last,
              'version': 'v1',
            },
          },
        ]);
      });
      addTearDown(client.dispose);
      await client.auth.setInitialSession(_session('owner'));

      final result = await SupabasePublishedAdaptiveWeekRepository(client)
          .read('goal-1', DateTime(2026, 11, 1, 23, 40));

      expect(result.preparationDecision, {
        'table': 'preparation_week_decisions',
        'version': 'v1',
      });
      expect(result.runningDecision, {
        'table': 'running_week_decisions',
        'version': 'v1',
      });
      expect(requests.map((r) => r.url.path), [
        '/rest/v1/preparation_week_decisions',
        '/rest/v1/running_week_decisions',
      ]);
      for (final request in requests) {
        expect(request.method, 'GET');
        expect(request.url.queryParameters, {
          'select': 'decision',
          'user_id': 'eq.owner',
          'preparation_goal_id': 'eq.goal-1',
          'week_start': 'eq.2026-10-26',
          'superseded_at': 'is.null',
        });
      }
    },
  );

  test(
    'una semana sin publicación devuelve ausencia sin calcular ni escribir',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) async {
        requests.add(request);
        return _response([]);
      });
      addTearDown(client.dispose);
      await client.auth.setInitialSession(_session('owner'));

      final result = await SupabasePublishedAdaptiveWeekRepository(client)
          .read('goal-1', DateTime(2026, 11, 2));

      expect(result.preparationDecision, isNull);
      expect(result.runningDecision, isNull);
      expect(requests, hasLength(2));
      expect(requests.every((r) => r.method == 'GET'), isTrue);
      expect(requests.first.url.queryParameters['week_start'], 'eq.2026-11-02');
    },
  );

  test('sin cuenta falla antes de HTTP', () async {
    final requests = <http.Request>[];
    final client = _client((request) async {
      requests.add(request);
      return _response([]);
    });
    addTearDown(client.dispose);

    await expectLater(
      SupabasePublishedAdaptiveWeekRepository(client)
          .read('goal-1', DateTime(2026, 11, 2)),
      throwsA(
        isA<PublishedAdaptiveWeekException>().having(
          (e) => e.message,
          'mensaje',
          contains('iniciar sesión'),
        ),
      ),
    );
    expect(requests, isEmpty);
  });

  test(
    'el fallo de red muestra un mensaje limpio y permite reintentar',
    () async {
      var fail = true;
      final client = _client((request) async {
        if (fail) throw http.ClientException('detalle interno sensible');
        return _response([]);
      });
      addTearDown(client.dispose);
      await client.auth.setInitialSession(_session('owner'));
      final repository = SupabasePublishedAdaptiveWeekRepository(client);

      await expectLater(
        repository.read('goal-1', DateTime(2026, 11, 2)),
        throwsA(
          isA<PublishedAdaptiveWeekException>().having(
            (e) => e.message,
            'mensaje',
            allOf(contains('Vuelve a intentarlo'), isNot(contains('sensible'))),
          ),
        ),
      );
      fail = false;
      expect(
        (await repository.read(
          'goal-1',
          DateTime(2026, 11, 2),
        )).preparationDecision,
        isNull,
      );
    },
  );

  for (final changedAt in [1, 2]) {
    test(
      'descarta datos si cambia la cuenta durante la lectura $changedAt',
      () async {
        final requests = <http.Request>[];
        final entered = Completer<void>();
        final release = Completer<void>();
        final client = _client((request) async {
          requests.add(request);
          if (requests.length == changedAt) {
            entered.complete();
            await release.future;
          }
          return _response([
            {
              'decision': {'owner': 'previous-account'},
            },
          ]);
        });
        addTearDown(client.dispose);
        await client.auth.setInitialSession(_session('owner'));

        final reading = SupabasePublishedAdaptiveWeekRepository(client)
            .read('goal-1', DateTime(2026, 11, 2));
        final rejected = expectLater(
          reading,
          throwsA(
            isA<PublishedAdaptiveWeekException>().having(
              (e) => e.message,
              'mensaje',
              contains('sesión ha cambiado'),
            ),
          ),
        );
        await entered.future;
        await client.auth.setInitialSession(_session('another-owner'));
        release.complete();
        await rejected;
        expect(requests, hasLength(changedAt));
        expect(requests.every((r) => r.method == 'GET'), isTrue);
        expect(
          requests.every((r) => r.url.queryParameters['user_id'] == 'eq.owner'),
          isTrue,
        );
      },
    );
  }
}

SupabaseClient _client(Future<http.Response> Function(http.Request) handler) =>
    SupabaseClient(
      'https://plan-fixture.example.test',
      'fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final response = await handler(request);
        return http.Response(
          response.body,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    );

http.Response _response(List<Map<String, dynamic>> rows) => http.Response(
  jsonEncode(rows),
  200,
  headers: {'content-type': 'application/json'},
);

String _session(String userId) => jsonEncode({
  'access_token':
      'eyJhbGciOiJIUzI1NiJ9.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000}))).replaceAll('=', '')}.fixture',
  'refresh_token': 'fixture-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': userId,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'fixture@example.test',
    'app_metadata': const {},
    'user_metadata': const {},
    'created_at': '2026-10-08T00:00:00Z',
  },
});

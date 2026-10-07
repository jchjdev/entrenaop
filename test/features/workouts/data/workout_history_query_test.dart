import 'dart:convert';
import 'dart:io';

import 'package:entrenaop/features/workouts/data/datasources/workout_remote_datasource_impl.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_history_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late _Client client;
  late WorkoutRemoteDataSourceImpl source;
  final requests = <Uri>[];
  setUp(() async {
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode([]));
      await request.response.close();
    });
    client = _Client('http://127.0.0.1:${server.port}');
    source = WorkoutRemoteDataSourceImpl(supabaseClient: client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });
  test('página estable, propietario, preparación y estado filtran antes del límite', () async {
    await source.getExecutionHistory(
      query: WorkoutHistoryQuery(
        limit: 31,
        preparationGoalId: 'goal',
        status: WorkoutExecutionStatus.completed,
        before: WorkoutHistoryCursor(
          startedAt: DateTime.utc(2026, 9, 20),
          id: '00000000-0000-0000-0000-000000000001',
        ),
      ),
    );
    final p = requests.single.queryParameters;
    expect(p['user_id'], 'eq.owner');
    expect(p['limit'], '31');
    expect(p['order'], 'started_at.desc.nullslast,id.desc.nullslast');
    expect(p['scheduled_workouts.preparation_goal_id'], 'eq.goal');
    expect(
      p['select'],
      contains('scheduled_workouts!inner(preparation_goal_id)'),
    );
    expect(p['status'], 'eq.completed');
    expect(p['or'], contains('id.lt.00000000-0000-0000-0000-000000000001'));
    expect(p['or'], contains('started_at.lt.2026-09-20T00:00:00.000Z'));
  });
  test('el intervalo incluye todo el último día civil', () async {
    final from = DateTime(2026, 10, 24);
    final through = DateTime(2026, 10, 25);
    await source.getExecutionHistory(
      query: WorkoutHistoryQuery(from: from, through: through),
    );
    final p = requests.single.queryParameters;
    expect(
      p['started_at'],
      'lt.${DateTime(2026, 10, 26).toUtc().toIso8601String()}',
    );
    expect(
      requests.single.query,
      contains(Uri.encodeComponent('gte.${from.toUtc().toIso8601String()}')),
    );
    expect(p['select'], isNot(contains('scheduled_workouts!inner')));
  });
  test(
    'sin sesión no consulta y un cursor inválido se rechaza antes de red',
    () async {
      client.testAuth.user = null;
      expect(await source.getExecutionHistory(), isEmpty);
      expect(requests, isEmpty);
      client.testAuth.user = _owner();
      await expectLater(
        source.getExecutionHistory(
          query: WorkoutHistoryQuery(
            before: WorkoutHistoryCursor(
              startedAt: DateTime.utc(2026),
              id: 'bad),id.gt.other',
            ),
          ),
        ),
        throwsArgumentError,
      );
      expect(requests, isEmpty);
    },
  );
}

class _Client extends SupabaseClient {
  _Client(String url)
    : super(
        url,
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
  final testAuth = _Auth();
  @override
  GoTrueClient get auth => testAuth;
}

class _Auth extends GoTrueClient {
  _Auth() : super(autoRefreshToken: false);
  User? user = _owner();
  @override
  User? get currentUser => user;
}

User _owner() => User(
  id: 'owner',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-07T00:00:00Z',
);

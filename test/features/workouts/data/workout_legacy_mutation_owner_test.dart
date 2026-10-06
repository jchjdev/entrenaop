import 'dart:convert';
import 'dart:io';

import 'package:entrenaop/features/workouts/data/services/workout_legacy_mutation_owner.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late _Client client;
  late WorkoutLegacyMutationOwner owner;
  final requests = <Uri>[];
  var visible = true;
  void Function()? onRequest;

  setUp(() async {
    requests.clear();
    visible = true;
    onRequest = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri);
      onRequest?.call();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          visible
              ? [
                  {'id': 'resource'},
                ]
              : [],
        ),
      );
      await request.response.close();
    });
    client = _Client('http://127.0.0.1:${server.port}');
    client.testAuth.user = _user('A');
    owner = WorkoutLegacyMutationOwner(client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('filtra el propietario exacto en todas las operaciones v1', () async {
    for (final type in WorkoutMutationType.values) {
      expect(await owner.owns(_mutation(type), 'A'), isTrue);
      final query = requests.last;
      expect(query.queryParameters['id'], 'eq.resource');
      if (type == WorkoutMutationType.completeSet ||
          type == WorkoutMutationType.skipSet) {
        expect(query.path, '/rest/v1/workout_execution_sets');
        expect(
          query.queryParameters['select'],
          'id,workout_executions!inner(user_id)',
        );
        expect(query.queryParameters['workout_executions.user_id'], 'eq.A');
      } else {
        expect(query.path, '/rest/v1/workout_executions');
        expect(query.queryParameters['user_id'], 'eq.A');
      }
    }
  });

  test('no consulta sin sesión o para una cuenta distinta', () async {
    expect(
      await owner.owns(_mutation(WorkoutMutationType.skipSet), 'B'),
      isFalse,
    );
    client.testAuth.user = null;
    expect(
      await owner.owns(_mutation(WorkoutMutationType.skipSet), 'A'),
      isFalse,
    );
    expect(requests, isEmpty);
  });

  test(
    'no recupera si el recurso real difiere del identificador guardado',
    () async {
      for (final type in [
        WorkoutMutationType.completeSet,
        WorkoutMutationType.completeAmrap,
      ]) {
        expect(
          await owner.owns(_mutation(type, mismatched: true), 'A'),
          isFalse,
        );
      }
      expect(requests, isEmpty);
    },
  );

  test('no atribuye a la cuenta una ejecución no visible', () async {
    visible = false;
    expect(
      await owner.owns(_mutation(WorkoutMutationType.finish), 'A'),
      isFalse,
    );
  });

  test(
    'descarta la comprobación si cambia la cuenta durante la consulta',
    () async {
      onRequest = () {
        client.testAuth.user = _user('B');
      };
      expect(
        await owner.owns(_mutation(WorkoutMutationType.finish), 'A'),
        isFalse,
      );
    },
  );
}

class _Client extends SupabaseClient {
  final testAuth = _Auth();

  _Client(String url)
    : super(
        url,
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

  @override
  GoTrueClient get auth => testAuth;
}

class _Auth extends GoTrueClient {
  _Auth() : super(autoRefreshToken: false);
  User? user;

  @override
  User? get currentUser => user;
}

User _user(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-06T00:00:00Z',
);

PendingWorkoutMutation _mutation(
  WorkoutMutationType type, {
  bool mismatched = false,
}) => PendingWorkoutMutation(
  userId: 'A',
  operationId: 'operation',
  type: type,
  resourceId: 'resource',
  values: {
    'p_result_id': mismatched ? 'other' : 'resource',
    'p_execution_id': mismatched ? 'other' : 'resource',
  },
  createdAt: DateTime.utc(2026),
);

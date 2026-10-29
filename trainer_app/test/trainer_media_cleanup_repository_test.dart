import 'dart:convert';
import 'dart:async';

import 'package:entrenaop_trainer/trainer_media_cleanup_repository.dart';
import 'package:entrenaop_trainer/trainer_catalog_trash_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trainer_exercise_repository_test.dart' as fixture;

Map<String, dynamic> cleanupReport() => {
  'items': <Object>[],
  'summary': {
    'pending': 1,
    'deleted': 0,
    'protected': 0,
    'freed_images': 0,
    'freed_bytes': 0,
  },
};

class CleanupServer extends fixture.ServerFixture {
  final cleanupCalls = <http.Request>[];
  int status = 200;
  bool invalidReceipt = false;
  Future<void> Function()? beforeCleanupReply;
  @override
  Future<http.Response> handle(http.Request request) async {
    if (request.url.path.endsWith('purge_trainer_catalog_item')) {
      final body = jsonDecode(request.body) as Map;
      return super.json(request, {
        'id': body['p_id'],
        'kind': body['p_kind'],
        'status': 'purged',
      });
    }
    if (!request.url.path.endsWith('trainer-media-cleanup')) {
      return super.handle(request);
    }
    cleanupCalls.add(request);
    if (beforeCleanupReply != null) await beforeCleanupReply!();
    final body = jsonDecode(request.body) as Map;
    return super.json(
      request,
      status != 200
          ? {'error': 'fixture failure'}
          : {
              ...cleanupReport(),
              if (body['operation_id'] != null)
                'receipt': {
                  'expected_user_id': invalidReceipt
                      ? 'another-owner'
                      : body['expected_user_id'],
                  'operation_id': body['operation_id'],
                  'action': body['action'],
                  'scope': body['scope'],
                  'kind': body['kind'],
                  'target': body['target'],
                },
            },
      status,
    );
  }
}

void main() {
  testWidgets(
    'purga confirmada deja de esperar al trabajador después de cinco segundos',
    (tester) async {
      final server = CleanupServer();
      await tester.runAsync(server.login);
      addTearDown(() => tester.runAsync(server.client.dispose));
      final gate = Completer<void>();
      var workerStarted = false, finished = false;
      final catalog = SupabaseTrainerCatalogTrashRepository(
        server.client,
        fixture.owner,
        cleanupAfterPurge: () {
          workerStarted = true;
          return gate.future;
        },
      );
      final pending = catalog
          .purge(
            fixture.operation,
            TrainerCatalogTrashEntry(
              id: 'exercise',
              name: 'Propio',
              kind: TrainerCatalogKind.exercise,
              trashedAt: DateTime.utc(2026, 10, 29),
            ),
          )
          .then((_) => finished = true);
      for (var frame = 0; frame < 3 && !workerStarted; frame++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(workerStarted, isTrue);
      await tester.pump(const Duration(seconds: 4));
      expect(finished, isFalse);
      await tester.pump(const Duration(seconds: 1));
      await pending;
      expect(finished, isTrue);
      gate.complete();
    },
  );

  test(
    'solicitudes fijan JWT y scope privado; inspect/run no crean otro UUID',
    () async {
      final server = CleanupServer();
      addTearDown(server.client.dispose);
      await server.login();
      final token = server.client.auth.currentSession!.accessToken;
      server.client.functions.headers['authorization'] = 'stale';
      final repository = SupabaseTrainerMediaCleanupRepository(
        server.client,
        fixture.owner,
      );
      await repository.inspect();
      await repository.sweep(fixture.operation);
      await repository.deleteVideo(fixture.operation, 'asset-id');
      await repository.run();
      final bodies = server.cleanupCalls
          .map((request) => jsonDecode(request.body) as Map)
          .toList();
      expect(bodies.map((body) => body['action']), [
        'inspect',
        'sweep',
        'delete',
        'run',
      ]);
      expect(bodies.first.containsKey('operation_id'), isFalse);
      expect(bodies.last.containsKey('operation_id'), isFalse);
      expect(bodies[2]['kind'], 'video');
      expect(bodies[2]['target'], 'asset-id');
      for (final (index, call) in server.cleanupCalls.indexed) {
        expect(call.headers['authorization'], 'Bearer $token');
        expect(bodies[index]['expected_user_id'], fixture.owner);
        expect(bodies[index]['scope'], 'trainer');
      }
    },
  );

  test('recibo ajeno o respuesta perdida no confirman una limpieza', () async {
    final server = CleanupServer()..invalidReceipt = true;
    addTearDown(server.client.dispose);
    await server.login();
    final repository = SupabaseTrainerMediaCleanupRepository(
      server.client,
      fixture.owner,
    );
    await expectLater(repository.sweep(fixture.operation), throwsStateError);
    final attempted = server.cleanupCalls.single.body;
    server.invalidReceipt = false;
    await repository.sweep(fixture.operation);
    expect(server.cleanupCalls.last.body, attempted);
    server.status = 503;
    await expectLater(
      repository.sweep(fixture.operation),
      throwsA(isA<FunctionException>()),
    );
    server.status = 403;
    await expectLater(
      repository.sweep(fixture.operation),
      throwsA(isA<FormatException>()),
    );
  });

  test('respuesta antigua tras cerrar cuenta se descarta', () async {
    final server = CleanupServer();
    addTearDown(server.client.dispose);
    await server.login();
    server.beforeCleanupReply = () => server.client.auth.signOut();
    await expectLater(
      SupabaseTrainerMediaCleanupRepository(
        server.client,
        fixture.owner,
      ).sweep(fixture.operation),
      throwsStateError,
    );
    expect(server.cleanupCalls, hasLength(1));
  });

  test(
    'fallo del trabajador no convierte una purga confirmada en error',
    () async {
      final server = CleanupServer()..status = 503;
      addTearDown(server.client.dispose);
      await server.login();
      final cleanup = SupabaseTrainerMediaCleanupRepository(
        server.client,
        fixture.owner,
      );
      final catalog = SupabaseTrainerCatalogTrashRepository(
        server.client,
        fixture.owner,
        cleanupAfterPurge: () async {
          await cleanup.run();
        },
      );
      await catalog.purge(
        fixture.operation,
        TrainerCatalogTrashEntry(
          id: 'exercise',
          name: 'Propio',
          kind: TrainerCatalogKind.exercise,
          trashedAt: DateTime.utc(2026, 10, 29),
        ),
      );
      expect(server.cleanupCalls, hasLength(1));
      expect(jsonDecode(server.cleanupCalls.single.body)['action'], 'run');
    },
  );
}

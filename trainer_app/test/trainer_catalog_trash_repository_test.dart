import 'dart:convert';

import 'package:entrenaop_trainer/trainer_catalog_trash_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'trainer_exercise_repository_test.dart' as fixture;

class _Server extends fixture.ServerFixture {
  final catalogRequests = <http.Request>[];
  String? errorCode;
  bool invalidReceipt = false;
  Future<void> Function()? beforeReply;
  List<Map<String, dynamic>> rows = [
    {
      'id': 'session',
      'kind': 'session',
      'name': 'Fuerza A',
      'trashed_at': '2026-10-29T12:00:00.123456Z',
      'revision': null,
      'delete_block_reason': 'Conserva pautas asignadas.',
    },
  ];

  @override
  Future<http.Response> handle(http.Request request) async {
    final name = request.url.pathSegments.last;
    if (!name.contains('trainer_catalog')) return super.handle(request);
    catalogRequests.add(request);
    if (beforeReply case final callback?) await callback();
    if (errorCode case final code?) {
      return super.json(request, {
        'code': code,
        'message': 'Contenido protegido',
      }, 400);
    }
    final params = jsonDecode(request.body) as Map;
    return super.json(
      request,
      name.startsWith('list_')
          ? rows
          : invalidReceipt
          ? {'status': 'ok'}
          : {
              'id': params['p_id'],
              'kind': params['p_kind'],
              'status': name.startsWith('trash_')
                  ? 'trashed'
                  : name.startsWith('restore_')
                  ? 'restored'
                  : 'purged',
              'trashed_at': name.startsWith('trash_')
                  ? '2026-10-29T12:00:00.123456Z'
                  : null,
            },
    );
  }
}

void main() {
  test('un 200 sin recibo válido sigue siendo resultado incierto', () async {
    final server = _Server();
    addTearDown(server.client.dispose);
    await server.login();
    final repository = SupabaseTrainerCatalogTrashRepository(
      server.client,
      fixture.owner,
    );
    final entry = (await repository.list(TrainerCatalogKind.session)).single;
    server.invalidReceipt = true;
    await expectLater(
      repository.restore(fixture.operation, entry),
      throwsStateError,
    );
    final attempted = server.catalogRequests.last.body;
    server.invalidReceipt = false;
    await repository.restore(fixture.operation, entry);
    expect(server.catalogRequests.last.body, attempted);
  });

  test(
    'contrato paginado, sello exacto y UUID estable al reintentar',
    () async {
      final server = _Server();
      addTearDown(server.client.dispose);
      await server.login();
      final repository = SupabaseTrainerCatalogTrashRepository(
        server.client,
        fixture.owner,
      );
      final entry = (await repository.list(TrainerCatalogKind.session)).single;
      expect(entry.blockedReason, 'Conserva pautas asignadas.');
      await repository.list(TrainerCatalogKind.session, before: entry);
      final cursor = jsonDecode(server.catalogRequests.last.body) as Map;
      expect(cursor['p_before_id'], 'session');
      expect(cursor['p_before_at'], '2026-10-29T12:00:00.123456Z');
      expect(cursor['p_limit'], 50);
      server.errorCode = 'PGRST000';
      await expectLater(
        repository.purge(fixture.operation, entry),
        throwsA(isNot(isA<FormatException>())),
      );
      final attempted = server.catalogRequests.last.body;
      server.errorCode = null;
      await repository.purge(fixture.operation, entry);
      expect(server.catalogRequests.last.body, attempted);
      expect(jsonDecode(attempted), {
        'p_operation_id': fixture.operation,
        'p_kind': 'session',
        'p_id': 'session',
        'p_trashed_at': '2026-10-29T12:00:00.123456Z',
      });
      expect(
        server.catalogRequests.last.headers['Authorization'],
        contains('Bearer '),
      );
    },
  );

  test(
    'sello obsoleto y denegación son errores definitivos y comprensibles',
    () async {
      final server = _Server();
      addTearDown(server.client.dispose);
      await server.login();
      final repository = SupabaseTrainerCatalogTrashRepository(
        server.client,
        fixture.owner,
      );
      final entry = (await repository.list(TrainerCatalogKind.session)).single;
      server.errorCode = '40001';
      await expectLater(
        repository.restore(fixture.operation, entry),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'mensaje',
            contains('Actualiza'),
          ),
        ),
      );
      server.errorCode = '42501';
      await expectLater(
        repository.trash(
          fixture.operation,
          TrainerCatalogKind.session,
          entry.id,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'mensaje',
            contains('permiso'),
          ),
        ),
      );
    },
  );

  test('no presenta ni envía datos con otra identidad, antes o después de la respuesta', () async {
    final server = _Server();
    addTearDown(server.client.dispose);
    await server.login();
    final other = SupabaseTrainerCatalogTrashRepository(
      server.client,
      'otra-cuenta',
    );
    await expectLater(other.list(TrainerCatalogKind.session), throwsStateError);
    expect(server.catalogRequests, isEmpty);
    final repository = SupabaseTrainerCatalogTrashRepository(
      server.client,
      fixture.owner,
    );
    server.beforeReply = () => server.client.auth.signOut();
    await expectLater(
      repository.trash(
        fixture.operation,
        TrainerCatalogKind.session,
        'session',
      ),
      throwsStateError,
    );
    expect(server.catalogRequests, hasLength(1));
  });

  test('rechaza mezclar recursos o cursores de otra biblioteca', () async {
    final server = _Server();
    addTearDown(server.client.dispose);
    await server.login();
    final repository = SupabaseTrainerCatalogTrashRepository(
      server.client,
      fixture.owner,
    );
    final session = (await repository.list(TrainerCatalogKind.session)).single;
    final count = server.catalogRequests.length;
    await expectLater(
      repository.list(TrainerCatalogKind.exercise, before: session),
      throwsFormatException,
    );
    expect(server.catalogRequests, hasLength(count));
    await expectLater(
      repository.list(TrainerCatalogKind.program),
      throwsFormatException,
    );
  });
}

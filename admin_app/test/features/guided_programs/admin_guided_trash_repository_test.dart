import 'dart:convert';
import 'dart:io';

import 'package:entrenaop_admin/features/guided_programs/data/supabase_admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/data/supabase_admin_guided_trash_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/data/supabase_admin_guided_work_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_trash.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  final requests = <(Uri, Map<String, dynamic>?)>[];
  final deleted = DateTime.utc(2026, 10, 21, 6, 15, 0, 123, 456);
  final program = {
    'id': 'p',
    'family_id': 'p',
    'version': 1,
    'status': 'draft',
    'content': {'name': 'Programa', 'mode': 'guide', 'phases': []},
  };
  Map<String, dynamic> work(String id, {bool trashed = false}) => {
    'id': id,
    'state': {'name': 'Trabajo'},
    'revision': 1,
    'base_program_id': 'p',
    'finalized_program_id': null,
    'discarded_at': null,
    'updated_at': deleted.toIso8601String(),
    'base_program': {'trashed_at': trashed ? deleted.toIso8601String() : null},
  };

  setUp(() async {
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      final body = request.method == 'POST'
          ? jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>?
          : null;
      requests.add((request.uri, body));
      Object? response;
      if (request.uri.path.endsWith('/list_admin_guided_program_trash')) {
        response = [
          {
            'kind': 'program',
            'id': 'p',
            'name': 'Programa',
            'trashed_at': deleted.toIso8601String(),
            'revision': null,
            'versions': 2,
            'work_count': 1,
          },
        ];
      } else if (request.uri.path.endsWith('/guided_programs')) {
        response = request.uri.queryParameters.containsKey('id')
            ? program
            : [program];
      } else if (request.uri.path.endsWith('/admin_guided_work_drafts')) {
        response = request.uri.queryParameters.containsKey('id')
            ? work('hidden', trashed: true)
            : [work('active'), work('hidden', trashed: true)];
      }
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('catálogo y enlaces directos excluyen versiones en papelera', () async {
    final repo = SupabaseAdminGuidedRepository(client);
    await repo.programs();
    await repo.program('p');
    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.$1.queryParameters['trashed_at'], 'is.null');
    }
  });

  test('el trabajo vinculado se oculta y su URL permanece cerrada mientras su familia está en papelera', () async {
    final repo = SupabaseAdminGuidedWorkRepository(client);
    expect((await repo.list()).map((w) => w.id), ['active']);
    expect((await repo.load('hidden'))!.discarded, isTrue);
    expect(
      requests.first.$1.queryParameters['select'],
      contains('base_program:guided_programs!'),
    );
  });

  test('recuperación de familia conserva los microsegundos del lote y solo usa RPC protegidas', () async {
    final repo = SupabaseAdminGuidedTrashRepository(client);
    final entry = (await repo.list()).single;
    expect(entry.versions, 2);
    await repo.trashProgram('version-2');
    await repo.restore(entry);
    expect(requests[1].$1.path, endsWith('/rpc/trash_admin_guided_program'));
    expect(requests[1].$2, {'p_program_id': 'version-2'});
    expect(
      requests.last.$1.path,
      endsWith('/rpc/restore_admin_guided_program'),
    );
    expect(requests.last.$2, {
      'p_family_id': 'p',
      'p_trashed_at': deleted.toIso8601String(),
    });
  });

  test(
    'recuperar trabajo envía su revisión sin modificar el programa de origen',
    () async {
      final repo = SupabaseAdminGuidedTrashRepository(client);
      await repo.restore(
        GuidedTrashEntry(
          id: 'work',
          name: 'Trabajo',
          isWork: true,
          trashedAt: deleted,
          revision: 7,
        ),
      );
      expect(
        requests.single.$1.path,
        endsWith('/rpc/restore_admin_guided_work'),
      );
      expect(requests.single.$2, {'p_id': 'work', 'p_revision': 7});
    },
  );
}

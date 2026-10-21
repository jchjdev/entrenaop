import 'dart:async';
import 'dart:convert';

import 'package:entrenaop_trainer/trainer_program_work_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_editor_ui/guided_program_work.dart';

import 'trainer_exercise_repository_test.dart' show ServerFixture, owner;
import 'trainer_program_flow_test.dart' show privateProgram;

const workId = '20000000-0000-4000-8000-000000000001';
const otherOwner = '10000000-0000-4000-8000-000000000002';

Map<String, dynamic> rawState([String name = 'Sin terminar']) => {
  'schema': 1,
  'name': name,
  'description': '',
  'audience': '',
  'equipment': '',
  'mode': 'phased',
  'categories': [],
  'primary': null,
  'phases': [
    {
      'name': 'Base',
      'weeks': 'sin terminar',
      'instructions': '',
      'pending': [],
      'replacements': {},
      'sessions': [
        {
          'id': 'template',
          'name': 'Fuerza A',
          'warmup': null,
          'adjustable': false,
          'minimum': '-',
          'maximum': '180',
        },
      ],
    },
  ],
};

Map<String, dynamic> workRow(
  int revision,
  Map<String, dynamic> state, {
  String lifecycle = 'open',
  String? base = 'program',
  String? finalized,
}) => {
  'id': workId,
  'context': 'trainer_private',
  'state': state,
  'revision': revision,
  'base_program_id': base,
  'finalized_program_id': finalized,
  'updated_at': '2026-10-21T10:00:00Z',
  'discarded_at': lifecycle == 'discarded' ? '2026-10-21T10:00:00Z' : null,
  'lifecycle': lifecycle,
};

Map<String, dynamic> envelope(
  Map<String, dynamic> work, {
  int? currentRevision,
  String? currentLifecycle,
}) => {
  'receipt': {'work': work},
  'current_revision': currentRevision ?? work['revision'],
  'current_lifecycle': currentLifecycle ?? work['lifecycle'],
};

class ProgramWorkServer extends ServerFixture {
  final calls = <({String name, Map<String, dynamic> params})>[];
  String loginOwner = owner;
  bool replaceTransportIdentity = false;
  int writes = 0;
  Future<http.Response> Function(
    http.Request request,
    String name,
    Map<String, dynamic> params,
  )?
  respond;

  @override
  Future<http.Response> handle(http.Request request) async {
    if (request.url.path == '/auth/v1/token') {
      requests.add(request);
      final payload = base64Url
          .encode(
            utf8.encode(jsonEncode({'sub': loginOwner, 'exp': 4102444800})),
          )
          .replaceAll('=', '');
      return super.json(request, {
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.fixture',
        'refresh_token': 'fixture',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': loginOwner,
          'aud': 'authenticated',
          'role': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-10-21T00:00:00Z',
        },
      });
    }
    if (request.url.path.contains('/rpc/')) {
      requests.add(request);
      final params = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      final name = request.url.pathSegments.last;
      calls.add((name: name, params: params));
      // Simula credenciales B al llegar al servidor después del check A.
      // El cliente todavía cree ser A: el guard expected_owner es imprescindible.
      if (replaceTransportIdentity) {
        request.headers['Authorization'] = 'Bearer B';
      }
      final actor = replaceTransportIdentity ? otherOwner : loginOwner;
      if (params['p_expected_owner'] != actor) {
        return super.json(request, {
          'code': '42501',
          'message': 'Cuenta distinta',
        }, 403);
      }
      return respond!(request, name, params);
    }
    return super.handle(request);
  }

  Future<void> loginAs(String id) async {
    loginOwner = id;
    await login();
  }
}

void main() {
  late ProgramWorkServer server;
  late SupabaseTrainerProgramWorkRepository repository;
  setUp(() async {
    server = ProgramWorkServer();
    await server.login();
    repository = SupabaseTrainerProgramWorkRepository(server.client, owner);
  });
  tearDown(() async => server.client.dispose());

  test(
    'revisión consumida por otra petición es conflicto, schema inválido no',
    () async {
      var message =
          'El reintento no coincide con la petición de trabajo original.';
      server.respond = (request, name, params) async =>
          server.json(request, {'code': '22023', 'message': message}, 400);
      const work = GuidedWork(id: workId, state: {});
      await expectLater(
        repository.save(work, rawState()),
        throwsA(isA<GuidedWorkConflict>()),
      );
      message = 'Estado de trabajo inválido.';
      await expectLater(
        repository.save(work, rawState()),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  test(
    'list/load/save conservan estado crudo y expected_owner en todas las RPC',
    () async {
      final raw = rawState();
      server.respond = (request, name, params) async =>
          server.json(request, switch (name) {
            'list_trainer_program_work' => [workRow(3, raw)],
            'get_trainer_program_work' => workRow(3, raw),
            'save_trainer_program_work' => envelope(
              workRow(4, params['p_state'] as Map<String, dynamic>),
            ),
            _ => throw StateError(name),
          });
      expect((await repository.list()).single.revision, 3);
      final loaded = (await repository.load(workId))!;
      final saved = await repository.save(loaded, rawState('Otro nombre'));
      expect(saved.revision, 4);
      expect((saved.state['phases'] as List).single['weeks'], 'sin terminar');
      expect(
        (saved.state['phases'] as List).single['sessions'][0]['minimum'],
        '-',
      );
      for (final call in server.calls) {
        expect(call.params['p_expected_owner'], owner);
      }
      expect(server.calls.last.params['p_base_program_id'], 'program');
      expect(server.calls.last.params['p_revision'], 3);
      expect(server.calls.last.params['p_state'], rawState('Otro nombre'));
    },
  );

  test(
    'un no-op nuevo avanza revisión y permite otra petición tras ese recibo',
    () async {
      final state = rawState();
      server.respond = (request, name, params) async => server.json(
        request,
        envelope(
          workRow(
            (params['p_revision'] as int) + 1,
            params['p_state'] as Map<String, dynamic>,
          ),
        ),
      );
      final work = GuidedWork(
        id: workId,
        state: state,
        revision: 3,
        baseProgramId: 'program',
      );
      final noOpReceipt = await repository.save(work, state);
      expect(noOpReceipt.revision, 4);
      final changed = await repository.save(
        noOpReceipt,
        rawState('Nueva petición'),
      );
      expect(changed.revision, 5);
      expect(server.calls.last.params['p_revision'], 4);
    },
  );

  test(
    'recibo antiguo con head posterior es conflicto, nunca éxito del head',
    () async {
      final original = rawState('A');
      server.respond = (request, name, params) async => server.json(request, {
        ...envelope(workRow(2, original), currentRevision: 3),
        'head': workRow(3, rawState('B')),
      });
      await expectLater(
        repository.save(
          GuidedWork(
            id: workId,
            state: {},
            revision: 1,
            baseProgramId: 'program',
          ),
          original,
        ),
        throwsA(isA<GuidedWorkConflict>()),
      );
    },
  );

  test(
    'un head con payload diferente no sustituye al recibo solicitado',
    () async {
      server.respond = (request, name, params) async =>
          server.json(request, envelope(workRow(2, rawState('B'))));
      await expectLater(
        repository.save(
          const GuidedWork(
            id: workId,
            state: {},
            revision: 1,
            baseProgramId: 'program',
          ),
          rawState('A'),
        ),
        throwsA(isA<GuidedWorkConflict>()),
      );
    },
  );

  test('controlador común reintenta A incierta antes de enviar B con revisión nueva', () async {
    var call = 0;
    server.respond = (request, name, params) async {
      call++;
      if (call == 1) {
        return server.json(request, {
          'code': 'PGRST000',
          'message': 'Respuesta perdida',
        }, 503);
      }
      return server.json(
        request,
        envelope(workRow(call, params['p_state'] as Map<String, dynamic>)),
      );
    };
    final initial = rawState('Original');
    final controller = GuidedWorkController(
      repository,
      GuidedWork(
        id: workId,
        state: initial,
        revision: 1,
        baseProgramId: 'program',
      ),
      initial,
    );
    addTearDown(controller.dispose);
    controller.update(rawState('A'));
    await expectLater(controller.flush(), throwsA(isA<PostgrestException>()));
    controller.update(rawState('B'));
    await controller.flush();
    expect(server.calls.map((c) => c.params['p_revision']), [1, 1, 2]);
    expect(server.calls[0].params, server.calls[1].params);
    expect((server.calls[2].params['p_state'] as Map)['name'], 'B');
    expect(controller.work.state['name'], 'B');
    expect(controller.dirty, isFalse);
  });

  test(
    'un recibo cerrado no limpia la petición pendiente del controlador',
    () async {
      server.respond = (request, name, params) async => server.json(
        request,
        envelope(
          workRow(2, rawState('A')),
          currentRevision: 3,
          currentLifecycle: 'finalized',
        ),
      );
      final state = rawState('Original');
      final controller = GuidedWorkController(
        repository,
        GuidedWork(
          id: workId,
          state: state,
          revision: 1,
          baseProgramId: 'program',
        ),
        state,
      );
      addTearDown(controller.dispose);
      controller.update(rawState('A'));
      await expectLater(controller.flush(), throwsA(isA<GuidedWorkConflict>()));
      expect(controller.conflict, isTrue);
      expect(controller.dirty, isTrue);
      expect(controller.work.revision, 1);
      await expectLater(controller.flush(), throwsA(isA<GuidedWorkConflict>()));
      expect(server.calls.length, 1);
    },
  );

  test(
    'finalizar conserva id/revisión/payload y no genera otra operación',
    () async {
      var fail = true;
      server.respond = (request, name, params) async {
        if (fail) {
          return server.json(request, {
            'code': 'PGRST000',
            'message': 'Incierto',
          }, 503);
        }
        return server.json(request, 'program-version-exacta');
      };
      const work = GuidedWork(
        id: workId,
        state: {},
        revision: 4,
        baseProgramId: 'program',
      );
      await expectLater(
        repository.finalize(work, privateProgram),
        throwsA(isA<PostgrestException>()),
      );
      fail = false;
      expect(
        await repository.finalize(work, privateProgram),
        'program-version-exacta',
      );
      expect(server.calls.first.params, server.calls.last.params);
      expect(server.calls.last.params['p_expected_owner'], owner);
      expect(
        server.calls.last.params.keys,
        unorderedEquals([
          'p_expected_owner',
          'p_id',
          'p_revision',
          'p_content',
        ]),
      );
    },
  );

  test(
    'descartar exige recibo actual discarded y lleva expected_owner',
    () async {
      var stale = true;
      server.respond = (request, name, params) async => server.json(
        request,
        envelope(
          workRow(5, rawState(), lifecycle: 'discarded'),
          currentRevision: stale ? 6 : 5,
        ),
      );
      const work = GuidedWork(
        id: workId,
        state: {},
        revision: 4,
        baseProgramId: 'program',
      );
      await expectLater(
        repository.discard(work),
        throwsA(isA<GuidedWorkConflict>()),
      );
      stale = false;
      await repository.discard(work);
      expect(server.calls.last.params, {
        'p_expected_owner': owner,
        'p_id': workId,
        'p_revision': 4,
      });
    },
  );

  test(
    'cabeceras B tras check A se rechazan por expected_owner antes de escribir',
    () async {
      server.replaceTransportIdentity = true;
      server.respond = (request, name, params) async {
        server.writes++;
        return server.json(
          request,
          envelope(workRow(1, params['p_state'] as Map<String, dynamic>)),
        );
      };
      await expectLater(
        repository.save(
          const GuidedWork(id: workId, state: {}),
          rawState('Datos de A'),
        ),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
        ),
      );
      expect(server.client.auth.currentUser!.id, owner);
      expect(server.calls.single.params['p_expected_owner'], owner);
      expect(server.writes, 0);
    },
  );

  test(
    'cambio real de cuenta durante await no acepta la respuesta anterior',
    () async {
      final response = Completer<http.Response>();
      final started = Completer<http.Request>();
      server.respond = (request, name, params) {
        started.complete(request);
        return response.future;
      };
      final pending = repository.load(workId);
      final assertion = expectLater(pending, throwsStateError);
      final request = await started.future;
      await server.loginAs(otherOwner);
      response.complete(server.json(request, workRow(3, rawState('Cuenta A'))));
      await assertion;
      final count = server.calls.length;
      await expectLater(repository.list(), throwsStateError);
      expect(server.calls.length, count);
    },
  );
}

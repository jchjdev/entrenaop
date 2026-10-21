import 'dart:async';

import 'package:entrenaop_trainer/trainer_workout_work_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trainer_exercise_repository_test.dart' show owner;
import 'trainer_program_work_repository_test.dart' show ProgramWorkServer;

const workId = '20000000-0000-4000-8000-000000000011';
const resultId = '20000000-0000-4000-8000-000000000012';
const origin = <String, dynamic>{
  'baseId': null,
  'programId': null,
  'parentWorkId': null,
  'phaseId': null,
  'positionId': null,
  'duplicate': false,
};

Map<String, dynamic> rawState([String name = 'Sin terminar']) => {
  'schema': 1,
  'context': <String, dynamic>{},
  'editor': {
    'schema': 1,
    'running': false,
    'nameText': name,
    'descriptionText': '',
    'durationText': 'pendiente',
    'segments': [],
    'blocks': [],
  },
};

Map<String, dynamic> workRow(
  int revision,
  Map<String, dynamic> state, {
  String lifecycle = 'open',
  Map<String, dynamic> workOrigin = origin,
}) => {
  'id': workId,
  'context': 'trainer_private',
  'origin': workOrigin,
  'state': state,
  'revision': revision,
  'result_id': lifecycle == 'finalized' ? resultId : null,
  'lifecycle': lifecycle,
  'updated_at': '2026-10-21T10:00:00Z',
};

Map<String, dynamic> envelope(
  Map<String, dynamic> row, {
  int? head,
  String? lifecycle,
}) => {
  'receipt': {'work': row},
  'current_revision': head ?? row['revision'],
  'current_lifecycle': lifecycle ?? row['lifecycle'],
};

void main() {
  late ProgramWorkServer server;
  late SupabaseTrainerWorkoutWorkRepository repository;
  setUp(() async {
    server = ProgramWorkServer();
    await server.login();
    repository = SupabaseTrainerWorkoutWorkRepository(server.client, owner);
  });
  tearDown(() async => server.client.dispose());

  test('list resume y load restaura intención y campos crudos', () async {
    final raw = rawState()
      ..['intent'] = {'name': 'Receta pendiente de confirmar', 'blocks': []};
    server.respond = (request, name, params) async => server.json(
      request,
      name == 'list_trainer_session_work'
          ? [
              workRow(4, {
                'editor': {'nameText': 'Sin terminar'},
                'intent': true,
              }),
            ]
          : workRow(4, raw),
    );
    final summary = (await repository.list()).single;
    expect(summary.state['schema'], isNull);
    final restored = (await repository.load(workId))!;
    expect(restored.state, raw);
    expect(restored.state['editor']['durationText'], 'pendiente');
    expect(restored.revision, 4);
    expect(
      server.calls.every((c) => c.params['p_expected_owner'] == owner),
      true,
    );
  });

  test(
    'save captura payload antes de await y exige recibo de ese estado',
    () async {
      final raw = rawState();
      final gate = Completer<void>();
      server.respond = (request, name, params) async {
        await gate.future;
        return server.json(
          request,
          envelope(workRow(1, params['p_state'] as Map<String, dynamic>)),
        );
      };
      final pending = repository.save(
        const WorkoutEditorWork(id: workId, origin: origin),
        raw,
      );
      raw['editor']['nameText'] = 'Cambio durante envío';
      gate.complete();
      final saved = await pending;
      expect(saved.state['editor']['nameText'], 'Sin terminar');
      expect(server.calls.single.params['p_revision'], 0);
      expect(server.calls.single.params['p_origin'], origin);
    },
  );

  test('un recibo antiguo con HEAD posterior no confirma autosave', () async {
    server.respond = (request, name, params) async =>
        server.json(request, envelope(workRow(2, rawState()), head: 3));
    await expectLater(
      repository.save(
        const WorkoutEditorWork(id: workId, origin: origin, revision: 1),
        rawState(),
      ),
      throwsA(isA<WorkoutWorkConflict>()),
    );
  });

  test(
    'origen distinto en recibo conserva conflicto aunque coincidan IDs',
    () async {
      server.respond = (request, name, params) async => server.json(
        request,
        envelope(
          workRow(1, rawState(), workOrigin: {...origin, 'baseId': resultId}),
        ),
      );
      await expectLater(
        repository.save(
          const WorkoutEditorWork(id: workId, origin: origin),
          rawState(),
        ),
        throwsA(isA<WorkoutWorkConflict>()),
      );
    },
  );

  test('recibo de payload distinto nunca se acepta como guardado', () async {
    server.respond = (request, name, params) async =>
        server.json(request, envelope(workRow(1, rawState('Otra pestaña'))));
    await expectLater(
      repository.save(
        const WorkoutEditorWork(id: workId, origin: origin),
        rawState(),
      ),
      throwsA(isA<WorkoutWorkConflict>()),
    );
  });

  test(
    'reopen devuelve un final ya confirmado y no limpia su intención',
    () async {
      final raw = rawState()..['intent'] = {'name': 'Final'};
      server.respond = (request, name, params) async => server.json(
        request,
        envelope(workRow(2, raw, lifecycle: 'finalized')),
      );
      final restored = await repository.reopen(
        WorkoutEditorWork(id: workId, origin: origin, revision: 1, state: raw),
      );
      expect(restored.resultId, resultId);
      expect(restored.state, raw);
      expect(server.calls.single.name, 'reopen_trainer_session_work');
    },
  );

  test('replay de reopen antiguo no cancela una intención posterior', () async {
    server.respond = (request, name, params) async =>
        server.json(request, envelope(workRow(2, rawState()), head: 3));
    await expectLater(
      repository.reopen(
        const WorkoutEditorWork(id: workId, origin: origin, revision: 1),
      ),
      throwsA(isA<WorkoutWorkConflict>()),
    );
  });

  test('discard exige recibo actual cerrado y revisión siguiente', () async {
    server.respond = (request, name, params) async => server.json(
      request,
      envelope(workRow(4, rawState(), lifecycle: 'discarded')),
    );
    await repository.discard(
      const WorkoutEditorWork(id: workId, origin: origin, revision: 3),
    );
    server.respond = (request, name, params) async => server.json(
      request,
      envelope(workRow(4, rawState(), lifecycle: 'open')),
    );
    await expectLater(
      repository.discard(
        const WorkoutEditorWork(id: workId, origin: origin, revision: 3),
      ),
      throwsA(isA<WorkoutWorkConflict>()),
    );
  });

  test(
    'finalizar usa trabajo/revisión durables, sin volver a enviar receta',
    () async {
      server.respond = (request, name, params) async =>
          server.json(request, resultId);
      expect(
        await repository.finalize(
          const WorkoutEditorWork(id: workId, origin: origin, revision: 7),
        ),
        resultId,
      );
      expect(server.calls.single.name, 'finalize_trainer_session_work');
      expect(server.calls.single.params, {
        'p_expected_owner': owner,
        'p_id': workId,
        'p_revision': 7,
      });
    },
  );

  test('40001 y replay divergente son conflicto; errores de dominio conservan tipo', () async {
    var code = '40001';
    var message = 'Otra pestaña';
    server.respond = (request, name, params) async =>
        server.json(request, {'code': code, 'message': message}, 400);
    const work = WorkoutEditorWork(id: workId, origin: origin);
    await expectLater(
      repository.save(work, rawState()),
      throwsA(isA<WorkoutWorkConflict>()),
    );
    code = '22023';
    message = 'El reintento no coincide con la petición de trabajo original.';
    await expectLater(
      repository.finalize(work),
      throwsA(isA<WorkoutWorkConflict>()),
    );
    message = 'Receta inválida';
    await expectLater(
      repository.finalize(work),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'barrera expected_owner rechaza cambio de headers A→B en seis RPC',
    () async {
      server.replaceTransportIdentity = true;
      const work = WorkoutEditorWork(id: workId, origin: origin);
      for (final run in <Future<Object?> Function()>[
        repository.list,
        () => repository.load(workId),
        () => repository.save(work, rawState()),
        () => repository.finalize(work),
        () => repository.reopen(work),
        () async {
          await repository.discard(work);
          return null;
        },
      ]) {
        await expectLater(run(), throwsA(isA<PostgrestException>()));
      }
      expect(server.calls.length, 6);
      expect(
        server.calls.every((c) => c.params['p_expected_owner'] == owner),
        true,
      );
    },
  );
}

import 'package:entrenaop_trainer/trainer_assignment_work_repository.dart';
import 'package:entrenaop_trainer/trainer_session_work_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

import 'trainer_exercise_repository_test.dart' show owner;
import 'trainer_program_work_repository_test.dart' show ProgramWorkServer;
import 'trainer_workout_work_repository_test.dart'
    show workId, resultId, rawState, workRow;

void main() {
  late ProgramWorkServer server;
  final origin = trainerSessionWorkOrigin(
    baseId: resultId,
    assignmentId: resultId,
    planningRevision: 4,
  );
  WorkoutEditorWork work() => WorkoutEditorWork(
    id: workId,
    origin: origin,
    state: rawState(),
    revision: 3,
  );
  setUp(() async {
    server = ProgramWorkServer();
    await server.login();
  });
  tearDown(() async => server.client.dispose());

  test('exige revisión del servidor y conserva huella y propietario', () async {
    var reviewed = false;
    server.respond = (request, name, params) async {
      switch (name) {
        case 'get_trainer_session_work':
          return server.json(
            request,
            workRow(3, rawState(), workOrigin: origin),
          );
        case 'preview_trainer_assignment_session_work':
          expect(params['p_expected_owner'], owner);
          expect(params['p_revision'], 3);
          return server.json(request, {
            'fingerprint': 'calendar-and-intent',
            'has_date_coincidence': true,
          });
        case 'finalize_trainer_assignment_session_work':
          expect(reviewed, true);
          expect(params['p_fingerprint'], 'calendar-and-intent');
          expect(params['p_expected_owner'], owner);
          return server.json(request, resultId);
        default:
          fail('No debe utilizar la finalización de biblioteca: $name');
      }
    };
    final repository = SupabaseTrainerAssignmentWorkRepository(
      server.client,
      owner,
      review: (coincidence) async {
        expect(coincidence, true);
        reviewed = true;
      },
    );
    expect(await repository.finalize(work()), resultId);
  });

  test(
    'rechazar coincidencia conserva intención sin aplicar cambios',
    () async {
      server.respond = (request, name, params) async => server.json(
        request,
        name == 'get_trainer_session_work'
            ? workRow(3, rawState(), workOrigin: origin)
            : {'fingerprint': 'preview', 'has_date_coincidence': true},
      );
      final repository = SupabaseTrainerAssignmentWorkRepository(
        server.client,
        owner,
        review: (_) async => throw StateError('Seguir editando'),
      );
      await expectLater(repository.finalize(work()), throwsStateError);
      expect(server.calls.any((c) => c.name.startsWith('finalize')), false);
    },
  );

  test('respuesta perdida recupera recibo sin repetir adaptación', () async {
    var committed = false;
    var reviews = 0;
    server.respond = (request, name, params) async {
      if (name == 'get_trainer_session_work') {
        return server.json(
          request,
          workRow(
            committed ? 4 : 3,
            rawState(),
            workOrigin: origin,
            lifecycle: committed ? 'finalized' : 'open',
          ),
        );
      }
      if (name.startsWith('preview')) {
        return server.json(request, {'fingerprint': 'preview'});
      }
      committed = true;
      throw StateError('Respuesta de confirmación perdida');
    };
    final repository = SupabaseTrainerAssignmentWorkRepository(
      server.client,
      owner,
      review: (_) async {
        reviews++;
      },
    );
    expect(await repository.finalize(work()), resultId);
    expect(await repository.finalize(work()), resultId);
    expect(reviews, 1);
    expect(
      server.calls.where((c) => c.name.startsWith('finalize')),
      hasLength(1),
    );
  });

  test(
    'revisión concurrente impide previsualizar o aplicar estado antiguo',
    () async {
      server.respond = (request, name, params) async =>
          server.json(request, workRow(4, rawState(), workOrigin: origin));
      final repository = SupabaseTrainerAssignmentWorkRepository(
        server.client,
        owner,
        review: (_) async => fail('No debe revisar un checkpoint antiguo'),
      );
      await expectLater(
        repository.finalize(work()),
        throwsA(isA<WorkoutWorkConflict>()),
      );
      expect(server.calls, hasLength(1));
    },
  );
}

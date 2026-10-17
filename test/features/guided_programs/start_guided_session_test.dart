import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/guided_programs/domain/start_guided_session.dart';
import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';
import 'package:workout_core/guided_program.dart';

import '../../support/guided_program_fixture.dart';

class _SwitchingWorkouts extends GuidedTestWorkouts {
  _SwitchingWorkouts(this.repository);
  final GuidedTestRepository repository;
  @override
  Future<void> syncPendingMutations() async {
    repository.owner = 'another-account';
  }
}

void main() {
  test('el siguiente paso retoma una ejecución abierta aunque se eligiera fuera de orden', () {
    const program = GuidedProgram(
      name: 'Guía',
      mode: GuidedProgramMode.guide,
      phases: [
        GuidedPhase(
          name: 'Trabajo',
          sessions: [
            GuidedSession(templateId: 'a', name: 'A'),
            GuidedSession(templateId: 'b', name: 'B'),
            GuidedSession(templateId: 'c', name: 'C'),
          ],
        ),
      ],
    );
    const detail = GuidedProgramDetail(
      program,
      follow: GuidedFollow(id: 'follow', phaseIndex: 0, completed: false),
      runs: [
        GuidedRun(phaseIndex: 0, sessionIndex: 2, status: 'in_progress'),
        GuidedRun(phaseIndex: 0, sessionIndex: 0, status: 'completed'),
      ],
    );
    expect(detail.nextSession, 2);
  });
  test(
    'cambiar de cuenta durante la sincronización detiene el inicio',
    () async {
      final repository = GuidedTestRepository();
      final launch = StartGuidedSession(
        repository: repository,
        workouts: _SwitchingWorkouts(repository),
        programId: 'program',
        phaseIndex: 0,
        sessionIndex: 0,
        operationId: 'operation',
      );
      await expectLater(launch(omitWarmup: false), throwsStateError);
      expect(repository.starts, isEmpty);
    },
  );
  test('sincroniza cierres antes de iniciar y conserva operación/ajustes al reintentar', () async {
    final repository = GuidedTestRepository()..failFirst = true;
    final workouts = GuidedTestWorkouts(events: repository.events);
    final launch = StartGuidedSession(
      repository: repository,
      workouts: workouts,
      programId: 'program',
      phaseIndex: 0,
      sessionIndex: 0,
      operationId: 'same-operation',
    );
    await expectLater(
      launch(omitWarmup: true, restSeconds: 120),
      throwsStateError,
    );
    expect(
      await launch(omitWarmup: false, restSeconds: 180),
      'execution-guided',
    );
    expect(repository.events, ['sync', 'start', 'sync', 'start']);
    expect(
      repository.starts.every(
        (s) => s.operation == 'same-operation' && s.omit && s.rest == 120,
      ),
      isTrue,
    );
    expect(workouts.defaultStarts, 0);
  });
}

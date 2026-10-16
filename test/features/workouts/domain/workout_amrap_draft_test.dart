import 'package:entrenaop/features/workouts/domain/entities/workout_amrap_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/workout_amrap_fixture.dart';

void main() {
  final sets = amrapFixture().sets;
  test('el contador resta hasta cero y no acredita ejercicios', () {
    final draft = const WorkoutAmrapDraft().changeRounds(-1).changeRounds(1);
    expect(draft.rounds, '1');
    expect(draft.hasPartial, false);
    expect(sets.every((s) => s.actualReps == null), true);
  });
  test('cinco vueltas y cuatro sentadillas conservan el orden del parcial', () {
    const draft = WorkoutAmrapDraft(
      rounds: '5',
      hasPartial: true,
      partialItemOrder: 2,
      partialReps: '4',
    );
    expect(draft.validate(sets), isNull);
    final result = draft.toResult(
      executionId: 'session',
      blockOrder: 0,
      sequence: sets,
    );
    expect(result.completedRounds, 5);
    expect(result.partialItemOrder, 2);
    expect(result.partialReps, 4);
  });
  test('cero en el segundo ejercicio conserva el primero completado', () {
    final draft = const WorkoutAmrapDraft(
      hasPartial: true,
      partialItemOrder: 1,
    );
    final result = draft.toResult(
      executionId: 'session',
      blockOrder: 0,
      sequence: sets,
    );
    expect(result.partialItemOrder, 1);
    expect(result.partialReps, 0);
    final noPartial = draft
        .copyWith(partialItemOrder: 0)
        .toResult(executionId: 'session', blockOrder: 0, sequence: sets);
    expect(noPartial.partialItemOrder, isNull);
  });
  test('no enviar parciales desactivados ni datos inválidos', () {
    const stale = WorkoutAmrapDraft(
      hasPartial: false,
      partialItemOrder: 2,
      partialReps: '4',
    );
    expect(
      stale
          .toResult(executionId: 's', blockOrder: 0, sequence: sets)
          .partialReps,
      0,
    );
    for (final draft in [
      const WorkoutAmrapDraft(rounds: ''),
      const WorkoutAmrapDraft(rounds: '-1'),
      const WorkoutAmrapDraft(rounds: '1.5'),
      const WorkoutAmrapDraft(rounds: '2147483648'),
      const WorkoutAmrapDraft(hasPartial: true),
      const WorkoutAmrapDraft(hasPartial: true, partialItemOrder: 99),
      const WorkoutAmrapDraft(
        hasPartial: true,
        partialItemOrder: 2,
        partialReps: '-1',
      ),
      const WorkoutAmrapDraft(
        hasPartial: true,
        partialItemOrder: 2,
        partialReps: '10',
      ),
    ]) {
      expect(draft.validate(sets), isNotNull, reason: '$draft');
      expect(
        () => draft.toResult(executionId: 's', blockOrder: 0, sequence: sets),
        throwsArgumentError,
      );
    }
  });
}

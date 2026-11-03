import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:flutter_test/flutter_test.dart';

const _old = PreparationGoal(
  id: 'old',
  program: PreparationProgram(
    id: 'old-program',
    name: 'Antigua',
    kind: PreparationProgramKind.internalAssessment,
  ),
);
const _new = PreparationGoal(
  id: 'new',
  program: PreparationProgram(
    id: 'new-program',
    name: 'Nueva',
    kind: PreparationProgramKind.internalAssessment,
  ),
);
AdaptiveProgramProgress _progress(PreparationGoal goal, String status) =>
    AdaptiveProgramProgress(
      goalId: goal.id!,
      name: goal.program.name,
      status: status,
      message: 'Estado',
    );
PreparationOverview _overview(
  List<PreparationGoal> goals,
  List<AdaptiveProgramProgress> programs,
) => PreparationOverview(
  assessments: const [],
  preferences: null,
  goals: goals,
  weekStart: DateTime(2026, 11, 2),
  weeklyWorkouts: const [],
  programs: programs,
);

void main() {
  test('sin objetivos ni planes no elige una preparación ficticia', () {
    expect(_overview([], []).featuredPreparation, (goal: null, program: null));
  });
  test('un objetivo nuevo pendiente precede al antiguo finalizado sin activar otro generador', () {
    final overview = _overview(
      [_old, _new],
      [_progress(_old, 'complete'), _progress(_new, 'draft')],
    );
    expect(overview.featuredPreparation.goal, _new);
    expect(overview.featuredPreparation.program!.status, 'draft');
    expect(overview.activeProgram, isNull);
  });
  test(
    'el objetivo pendiente también se conserva antes de disponer de su resumen',
    () {
      final overview = _overview([_old, _new], [_progress(_old, 'complete')]);
      expect(overview.featuredPreparation.goal, _new);
      expect(overview.featuredPreparation.program, isNull);
    },
  );
  test('varios pendientes conservan el orden guardado sin elegir por última visita', () {
    final overview = _overview(
      [_old, _new],
      [_progress(_old, 'draft'), _progress(_new, 'draft')],
    );
    expect(overview.featuredPreparation.goal, _old);
  });
  test(
    'si todos han finalizado se conserva la primera preparación histórica',
    () {
      final overview = _overview(
        [_old, _new],
        [_progress(_old, 'complete'), _progress(_new, 'complete')],
      );
      expect(overview.featuredPreparation.goal, _old);
      expect(overview.featuredPreparation.program!.status, 'complete');
      expect(overview.activeProgram, isNull);
    },
  );
  for (final status in ['training', 'needs_review', 'paused']) {
    test(
      'la prioridad existente $status precede a otro objetivo pendiente',
      () {
        final current = _progress(_old, status);
        final overview = _overview(
          [_old, _new],
          [current, _progress(_new, 'draft')],
        );
        expect(overview.activeProgram, current);
        expect(overview.featuredPreparation.goal, _old);
        expect(overview.featuredPreparation.program, current);
      },
    );
  }
}

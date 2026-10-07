// Datos ficticios para comprobar y capturar widgets reales sin cuentas ni red.
import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/preparation_marks_page.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:entrenaop/features/program_assessment/data/program_assessment_repository.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';

const evolutionTroop = PreparationGoal(
  id: 'troop',
  program: PreparationProgram(
    id: PreparationProgramIds.armedForcesTroopEntry,
    name: 'Ingreso · Tropa y marinería',
    kind: PreparationProgramKind.internalAssessment,
  ),
);
const evolutionFas = PreparationGoal(
  id: 'fas',
  program: PreparationProgram(
    id: PreparationProgramIds.fasPeriodicAssessment,
    name: 'Evaluación periódica FAS · 2027',
    kind: PreparationProgramKind.internalAssessment,
  ),
);
const evolutionGeneric = PreparationGoal(
  id: 'generic',
  program: PreparationProgram(
    id: 'fixture-program',
    name: 'Preparación de pruebas físicas',
    kind: PreparationProgramKind.internalAssessment,
  ),
);

PreparationMarksData evolutionTroopData() => PreparationMarksData(
  goal: evolutionTroop,
  troop: [
    PhysicalAssessmentHistoryEntry(
      id: 'assessment',
      completedAt: DateTime(2026, 10, 5),
      report: AssessmentReport(
        catalogVersion: 'baremo-guardado-v1',
        category: AssessmentCategory.men,
        milestone: AssessmentMilestone.entry,
        results: const [
          AssessmentResult(
            passed: true,
            mark: RecordedMark(
              testId: 'push-ups',
              unit: MarkUnit.repetitions,
              value: 18,
            ),
            standard: AssessmentStandard(
              catalogVersion: 'baremo-guardado-v1',
              test: PhysicalTestDefinition(
                id: 'push-ups',
                name: 'Flexo-extensiones de brazos',
                unit: MarkUnit.repetitions,
                betterDirection: BetterDirection.higher,
              ),
              category: AssessmentCategory.men,
              milestone: AssessmentMilestone.entry,
              threshold: 12,
            ),
          ),
        ],
      ),
    ),
  ],
  running: [
    RunningTestResult(
      id: 'run',
      completedAt: DateTime(2026, 10, 6),
      durationSeconds: 540,
      rpe: 7,
      averageHrBpm: 152,
      maxHrBpm: 172,
      splitsSeconds: const [108, 108, 108, 108, 108],
      notes: 'Control guardado de 2 km.',
    ),
  ],
);

Future<PreparationMarksData> evolutionFasData({String? version}) async =>
    PreparationMarksData(
      goal: evolutionFas,
      fasReference: await FasPeriodic2027Reference.load(),
      fas: [
        FasPeriodicAssessmentEntry(
          id: 'fas-assessment',
          goalId: 'fas',
          scoringVersion: version ?? FasPeriodic2027Reference.version,
          completedAt: DateTime(2026, 10, 5),
          category: 'men',
          age: 30,
          isPreEffectiveReference: true,
          marks: const [
            FasPeriodicAssessmentMark(
              testId: 'upper_body_push_ups_2_min',
              testName: 'Flexo-extensiones (2 min)',
              unit: 'repetitions',
              value: 30,
              threshold: 18,
              meetsMinimum: true,
            ),
          ],
        ),
      ],
    );

PreparationMarksData evolutionGenericData() => PreparationMarksData(
  goal: evolutionGeneric,
  program: [
    ProgramAssessmentAttempt(
      id: 'saved-attempt',
      assessedOn: DateTime(2026, 9, 22),
      category: 'women',
      result: const ProgramAssessmentResult(
        passed: true,
        age: 28,
        version: 'snapshot-v3',
        total: 47.5,
        details: [
          ProgramAssessmentDetail(
            testId: 'jump',
            name: 'Salto horizontal',
            passed: true,
            mark: 2.15,
            points: 47.5,
          ),
        ],
      ),
      marks: const [
        AssessmentMarkInput(
          testId: 'jump',
          attempts: [
            AssessmentExerciseAttempt(valid: false),
            AssessmentExerciseAttempt(valid: true, mark: 2.15),
          ],
        ),
      ],
    ),
  ],
);

List<WorkoutExecution> evolutionSessions({int count = 65}) =>
    List.generate(count, (i) {
      final start = DateTime(2026, 10, 7, 9).subtract(Duration(days: i));
      return WorkoutExecution(
        id: 'session-$i',
        templateId: 'template',
        templateName: 'Entrenamiento ${i + 1} · Fuerza y carrera',
        templateVersion: 1,
        startedAt: start,
        completedAt: start.add(const Duration(minutes: 35)),
        status: i % 4 == 0
            ? WorkoutExecutionStatus.abandoned
            : WorkoutExecutionStatus.completed,
        finalRpe: 7,
        sets: const [],
      );
    });

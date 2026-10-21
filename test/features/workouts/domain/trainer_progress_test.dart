import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/performance_set.dart';
import 'package:workout_core/trainer_progress.dart';
import 'package:workout_core/workout_template.dart';

TrainerProgressDate day(int value) => TrainerProgressDate(2026, 10, value);
TrainerProgressPeriod get period =>
    TrainerProgressPeriod(startInclusive: day(1), endExclusive: day(22));

TrainerProgressAssignment assignment(
  String id,
  int date,
  TrainerProgressAssignmentStatus status, {
  String? executionId,
}) => TrainerProgressAssignment(
  id: id,
  scheduledDate: day(date),
  status: status,
  executionId: executionId,
);

TrainerComplianceSummary compliance(
  List<TrainerProgressAssignment> assignments,
) => summarizeTrainerCompliance(
  assignments: assignments,
  period: period,
  asOfDate: day(20),
);

TrainerProgressSetRecord set(
  String id, {
  String exercise = 'squat-v1',
  String execution = 'execution-1',
  int date = 10,
  TrainerProgressSetStatus status = TrainerProgressSetStatus.completed,
  WorkoutBlockFormat format = WorkoutBlockFormat.straightSets,
  int? reps,
  double? load,
  double? distance,
  double? duration,
  double? rpe,
  double? rir,
  PerformanceSetPrescription? prescription,
  PerformanceSetResult? result,
}) => TrainerProgressSetRecord(
  id: id,
  executionId: execution,
  exerciseId: exercise,
  recordDate: day(date),
  status: status,
  blockFormat: format,
  actualReps: reps,
  actualLoadKg: load,
  actualDistanceMeters: distance,
  actualDurationSeconds: duration,
  actualRpe: rpe,
  actualRir: rir,
  performancePrescription: prescription,
  performanceResult: result,
);

TrainerExerciseResultsSummary results(
  List<TrainerProgressSetRecord> sets, {
  List<TrainerProgressAmrapRecord> amrap = const [],
}) => summarizeTrainerExerciseResults(
  sets: sets,
  period: period,
  amrapBlocks: amrap,
);

void main() {
  group('Fechas civiles y cumplimiento', () {
    test('rechaza fechas y periodos vacíos o invertidos', () {
      expect(() => TrainerProgressDate(2026, 2, 30), throwsArgumentError);
      expect(
        () =>
            TrainerProgressPeriod(startInclusive: day(2), endExclusive: day(2)),
        throwsArgumentError,
      );
      expect(
        () =>
            TrainerProgressPeriod(startInclusive: day(3), endExclusive: day(2)),
        throwsArgumentError,
      );
    });

    test('extrae componentes sin cambiar la fecha por zona horaria', () {
      expect(
        TrainerProgressDate.fromCalendarDate(
          DateTime.utc(2026, 10, 20, 23, 59),
        ),
        day(20),
      );
      expect(
        TrainerProgressDate.fromCalendarDate(DateTime(2026, 10, 20, 0, 1)),
        day(20),
      );
    });

    test('fronteras inicio incluido, final excluido, hoy aún no vencido', () {
      final summary = compliance([
        assignment('start', 1, TrainerProgressAssignmentStatus.completed),
        assignment('yesterday', 19, TrainerProgressAssignmentStatus.planned),
        assignment('today', 20, TrainerProgressAssignmentStatus.planned),
        assignment('future', 21, TrainerProgressAssignmentStatus.planned),
        assignment('end', 22, TrainerProgressAssignmentStatus.completed),
      ]);
      expect(summary.eligibleCount, 2);
      expect(summary.completedCount, 1);
      expect(summary.pendingCount, 1);
      expect(summary.todayAndFutureCount, 2);
      expect(summary.completedFraction, .5);
    });

    test(
      'completadas adelantadas cuentan; futuras no realizadas se separan',
      () {
        final summary = compliance([
          assignment('early', 21, TrainerProgressAssignmentStatus.completed),
          assignment(
            'progress',
            21,
            TrainerProgressAssignmentStatus.inProgress,
          ),
          assignment('skipped', 21, TrainerProgressAssignmentStatus.skipped),
          assignment(
            'abandoned',
            21,
            TrainerProgressAssignmentStatus.abandoned,
          ),
        ]);
        expect(summary.eligibleCount, 1);
        expect(summary.completedFraction, 1);
        expect(summary.todayAndFutureCount, 3);
        expect(
          summary.todayAndFuture[TrainerProgressAssignmentStatus.inProgress],
          1,
        );
      },
    );

    test('distingue todos los estados sin confundir omitir y cancelar', () {
      final summary = compliance([
        for (final status in TrainerProgressAssignmentStatus.values)
          assignment(status.name, 10, status),
      ]);
      expect(summary.eligibleCount, 5);
      expect(summary.completedCount, 1);
      expect(summary.pendingCount, 1);
      expect(summary.inProgressCount, 1);
      expect(summary.skippedCount, 1);
      expect(summary.abandonedCount, 1);
      expect(summary.cancelledExcluded, 1);
      expect(summary.completedFraction, .2);
    });

    test('sin evaluables no inventa porcentaje', () {
      expect(compliance([]).completedFraction, isNull);
      expect(
        compliance([
          assignment('cancel', 10, TrainerProgressAssignmentStatus.cancelled),
        ]).completedFraction,
        isNull,
      );
      expect(
        compliance([
          assignment('today', 20, TrainerProgressAssignmentStatus.planned),
        ]).completedFraction,
        isNull,
      );
    });

    test('deduplica páginas idénticas y rechaza estados contradictorios', () {
      final row = assignment(
        'same',
        10,
        TrainerProgressAssignmentStatus.completed,
      );
      expect(compliance([row, row]).eligibleCount, 1);
      expect(
        () => compliance([
          row,
          assignment('same', 10, TrainerProgressAssignmentStatus.planned),
        ]),
        throwsArgumentError,
      );
    });

    test('no cuenta una ejecución en dos pautas distintas', () {
      expect(
        () => compliance([
          assignment(
            'one',
            10,
            TrainerProgressAssignmentStatus.completed,
            executionId: 'execution',
          ),
          assignment(
            'two',
            10,
            TrainerProgressAssignmentStatus.completed,
            executionId: 'execution',
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('el resumen es inmutable', () {
      expect(() => compliance([]).evaluated.clear(), throwsUnsupportedError);
      expect(
        () => compliance([]).todayAndFuture.clear(),
        throwsUnsupportedError,
      );
    });
  });

  group('Resultados reales por ejercicio', () {
    test('ausente, cero y valor real permanecen diferenciados', () {
      final exercise = results([
        set('missing'),
        set('zero', reps: 0, load: 0),
        set('real', reps: 10, load: 20),
      ]).exercises['squat-v1']!;
      expect(exercise.reps.recordedCount, 2);
      expect(exercise.reps.missingCount, 1);
      expect(exercise.reps.recordedTotal, 10);
      expect(exercise.reps.minimum, 0);
      expect(exercise.reps.mean, 5);
      expect(exercise.loadKg.recordedTotal, isNull);
      expect(exercise.loadKg.mean, 10);
      expect(exercise.durationSeconds.recordedTotal, isNull);
      expect(exercise.durationSeconds.recordedCount, 0);
    });

    test('pendientes y omitidas no aportan resultados ni falsos ceros', () {
      final exercise = results([
        set('completed', reps: 5),
        set('pending', status: TrainerProgressSetStatus.pending, reps: 500),
        set('skipped', status: TrainerProgressSetStatus.skipped, reps: 1000),
      ]).exercises['squat-v1']!;
      expect(exercise.count(TrainerProgressSetStatus.completed), 1);
      expect(exercise.count(TrainerProgressSetStatus.pending), 1);
      expect(exercise.count(TrainerProgressSetStatus.skipped), 1);
      expect(exercise.reps.recordedTotal, 5);
      expect(exercise.reps.missingCount, 0);
    });

    test('separa identificadores/versiones y dimensiones físicas', () {
      final summary = results([
        set('strength', reps: 10, load: 50, duration: 30, rpe: 8, rir: 2),
        set('run', exercise: 'running', distance: 1000, duration: 300),
        set('version', exercise: 'squat-v2', reps: 20, load: 60),
      ]);
      expect(summary.exercises.length, 3);
      expect(summary.exercises['squat-v1']!.reps.recordedTotal, 10);
      expect(
        summary.exercises['squat-v1']!.distanceMeters.recordedTotal,
        isNull,
      );
      expect(summary.exercises['running']!.distanceMeters.recordedTotal, 1000);
      expect(summary.exercises['running']!.loadKg.mean, isNull);
      expect(summary.exercises['squat-v1']!.rpe.recordedTotal, isNull);
      expect(summary.exercises['squat-v1']!.rir.mean, 2);
    });

    test('fecha propia del registro filtra sin usar fecha de pauta', () {
      final summary = results([set('start', date: 1), set('end', date: 22)]);
      expect(summary.exercises['squat-v1']!.records.single.id, 'start');
    });

    test('conserva resultado deportivo sin convertirlo en reps heredadas', () {
      const recorded = PerformanceSetResult(value: 12, techniqueValid: false);
      final exercise = results([set('typed', result: recorded)])
          .exercises['squat-v1']!;
      expect(exercise.records.single.performanceResult, same(recorded));
      expect(exercise.reps.recordedTotal, isNull);
    });

    test('rechaza métricas no finitas y negativas de series completadas', () {
      for (final invalid in [double.nan, double.infinity, -1.0]) {
        expect(
          () => results([set('invalid', load: invalid)]),
          throwsArgumentError,
        );
      }
    });

    test('deduplica series idénticas y rechaza correcciones mezcladas', () {
      final row = set('same', reps: 10);
      expect(results([row, row]).exercises['squat-v1']!.reps.recordedTotal, 10);
      expect(() => results([row, set('same', reps: 11)]), throwsArgumentError);
    });

    test('no fabrica series, volumen o repeticiones a partir de AMRAP', () {
      final block = TrainerProgressAmrapRecord(
        executionId: 'execution-1',
        blockOrder: 0,
        recordDate: day(10),
        completedRounds: 3,
        partialItemOrder: 1,
        partialReps: 2,
      );
      final summary = results(
        [
          set(
            'reference',
            format: WorkoutBlockFormat.amrap,
            reps: 100,
            load: 20,
          ),
          set('actual', reps: 5),
        ],
        amrap: [block, block],
      );
      expect(summary.amrapReferenceSetsExcluded, 1);
      expect(summary.amrapBlocks.single.completedRounds, 3);
      expect(summary.exercises['squat-v1']!.reps.recordedTotal, 5);
      expect(summary.exercises['squat-v1']!.records.length, 1);
    });

    test(
      'AMRAP admite cero y conserva parcial sin asignarlo a un ejercicio',
      () {
        final summary = results(
          [],
          amrap: [
            TrainerProgressAmrapRecord(
              executionId: 'execution-1',
              blockOrder: 0,
              recordDate: day(10),
              completedRounds: 0,
            ),
          ],
        );
        expect(summary.exercises, isEmpty);
        expect(summary.amrapBlocks.single.completedRounds, 0);
        expect(summary.amrapBlocks.single.partialItemOrder, isNull);
      },
    );

    test('rechaza resultados AMRAP ambiguos o contradictorios', () {
      TrainerProgressAmrapRecord block(int rounds, {int partial = 0}) =>
          TrainerProgressAmrapRecord(
            executionId: 'execution-1',
            blockOrder: 0,
            recordDate: day(10),
            completedRounds: rounds,
            partialReps: partial,
          );
      expect(() => results([], amrap: [block(-1)]), throwsArgumentError);
      expect(
        () => results([], amrap: [block(1, partial: 2)]),
        throwsArgumentError,
      );
      expect(
        () => results([], amrap: [block(1), block(2)]),
        throwsArgumentError,
      );
    });

    test('colecciones de salida no permiten alterar el informe', () {
      final summary = results([set('one')]);
      expect(() => summary.exercises.clear(), throwsUnsupportedError);
      expect(() => summary.amrapBlocks.clear(), throwsUnsupportedError);
      expect(
        () => summary.exercises['squat-v1']!.records.clear(),
        throwsUnsupportedError,
      );
    });
  });
}

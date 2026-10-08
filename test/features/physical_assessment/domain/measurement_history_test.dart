import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/measurement_history.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_progress_calculator.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/assessment_formatters.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/preparation_measurement_history.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/evolution_fixtures.dart';
import '../../../helpers/measurement_comparison_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'ordena hechos y compara repeticiones, tiempo y plancha con su dirección',
    () {
      final data = comparisonMarksData();
      final series = preparationMeasurementHistory(
        troop: data.troop.reversed.toList(),
      );
      expect(series, hasLength(3));
      for (final item in series) {
        expect(item.samples.map((s) => s.id), [
          'assessment-6',
          'assessment-3',
          'assessment-1',
        ]);
        final progress = item.compare(
          previousId: 'assessment-3',
          currentId: 'assessment-6',
        )!;
        expect(progress.favorableDifference, switch (item.test.id) {
          'upper_body_push_ups_2_min' => 2,
          'abdominal_plank' => 0,
          _ => 20000,
        });
      }
      final run = series.singleWhere((s) => s.test.id == 'run_2000_m');
      expect(
        run
            .compare(previousId: 'assessment-1', currentId: 'assessment-3')!
            .favorableDifference,
        -10000,
      );
    },
  );

  for (final incompatible in [
    comparisonAssessment(day: 1, version: 'otra-version'),
    comparisonAssessment(day: 1, category: AssessmentCategory.women),
    comparisonAssessment(day: 1, milestone: AssessmentMilestone.endOfTraining),
  ]) {
    test(
      'separa versiones, columnas e hitos: ${incompatible.report.props.take(3)}',
      () {
        final current = comparisonAssessment();
        final series = preparationMeasurementHistory(
          troop: [current, incompatible],
        );
        expect(series, hasLength(6));
        expect(series.every((s) => !s.canCompare), isTrue);
        expect(
          const AssessmentProgressCalculator().compare(
            previous: incompatible,
            current: current,
          ),
          isEmpty,
        );
      },
    );
  }

  for (final incompatible in [
    comparisonAssessment(day: 1, pushUpUnit: MarkUnit.milliseconds),
    comparisonAssessment(day: 1, pushUpDirection: BetterDirection.lower),
  ]) {
    test(
      'no cruza unidades o dirección: ${incompatible.report.results.first.standard.test.props}',
      () {
        final current = comparisonAssessment();
        final series = preparationMeasurementHistory(
          troop: [current, incompatible],
        );
        expect(
          series
              .where((s) => s.test.id == 'upper_body_push_ups_2_min')
              .every((s) => !s.canCompare),
          isTrue,
        );
        expect(
          const AssessmentProgressCalculator()
              .compare(previous: incompatible, current: current)
              .map((p) => p.test.id),
          ['abdominal_plank', 'run_2000_m'],
        );
      },
    );
  }

  test(
    'no compara consigo mismo, fecha igual, invertida o registro de otra serie',
    () {
      final data = comparisonMarksData();
      final series = preparationMeasurementHistory(troop: data.troop).first;
      expect(
        series.compare(previousId: 'assessment-6', currentId: 'assessment-6'),
        isNull,
      );
      expect(
        series.compare(previousId: 'assessment-6', currentId: 'assessment-1'),
        isNull,
      );
      expect(
        series.compare(previousId: 'ajeno', currentId: 'assessment-6'),
        isNull,
      );
      final sameDate = MeasurementSeries(
        id: 'same',
        test: series.test,
        origin: series.origin,
        version: series.version,
        samples: [
          MeasurementSample(
            id: 'a',
            completedAt: DateTime(2026, 10, 6),
            value: 10,
          ),
          MeasurementSample(
            id: 'b',
            completedAt: DateTime(2026, 10, 6),
            value: 12,
          ),
        ],
      );
      expect(sameDate.canCompare, isFalse);
      expect(sameDate.compare(previousId: 'a', currentId: 'b'), isNull);
      expect(
        const AssessmentProgressCalculator().compare(
          previous: data.troop.first,
          current: data.troop.last,
        ),
        isEmpty,
      );
    },
  );

  test('controles separados de carrera oficial; otro protocolo no se interpreta como 2 km', () {
    final data = comparisonMarksData();
    final series = preparationMeasurementHistory(
      troop: data.troop,
      running: [
        ...data.running,
        RunningTestResult(
          id: 'different',
          protocolVersion: 'cooper-v1',
          completedAt: DateTime(2026, 10, 2),
          durationSeconds: 720,
          rpe: 7,
        ),
        RunningTestResult(
          id: 'bad',
          completedAt: DateTime(2026, 10, 4),
          durationSeconds: 15,
          rpe: 7,
        ),
      ],
    );
    final controls = series.singleWhere(
      (s) => s.origin == 'Control de carrera',
    );
    expect(controls.samples.map((s) => s.id), ['control-6', 'control-1']);
    expect(
      controls
          .compare(previousId: 'control-1', currentId: 'control-6')!
          .favorableDifference,
      20000,
    );
    expect(
      controls.compare(previousId: 'assessment-1', currentId: 'control-6'),
      isNull,
    );
    expect(controls.samples.first.context, 'RPE 8');
  });

  test('FAS compara mediciones de su versión, conserva edad y excluye unidades ajenas', () async {
    final data = await evolutionFasData();
    final first = data.fas.single;
    FasPeriodicAssessmentEntry before({
      String? version,
      String unit = 'repetitions',
      String category = 'men',
    }) => FasPeriodicAssessmentEntry(
      id: 'previous',
      goalId: first.goalId,
      scoringVersion: version ?? first.scoringVersion,
      completedAt: DateTime(2026, 10, 1),
      category: category,
      age: 29,
      isPreEffectiveReference: true,
      marks: [
        FasPeriodicAssessmentMark(
          testId: first.marks.single.testId,
          testName: first.marks.single.testName,
          unit: unit,
          value: 26,
          threshold: 18,
          meetsMinimum: true,
        ),
      ],
    );
    final series = preparationMeasurementHistory(
      fas: [first, before()],
      fasReference: data.fasReference,
    ).single;
    expect(
      series
          .compare(previousId: 'previous', currentId: first.id)!
          .favorableDifference,
      4,
    );
    expect(series.samples.map((s) => s.context), ['30 años', '29 años']);
    for (final other in [
      before(version: 'desconocida'),
      before(unit: 'seconds'),
      before(category: 'women'),
    ]) {
      expect(
        preparationMeasurementHistory(
          fas: [first, other],
          fasReference: data.fasReference,
        ).every((s) => !s.canCompare),
        isTrue,
      );
    }
    expect(preparationMeasurementHistory(fas: [first, before()]), isEmpty);
  });

  test('los valores y diferencias conservan milésimas; no truncan un cambio pequeño', () {
    const run = PhysicalTestDefinition(
      id: 'run_2000_m',
      name: 'Carrera',
      unit: MarkUnit.milliseconds,
      betterDirection: BetterDirection.lower,
    );
    const agility = PhysicalTestDefinition(
      id: 'agility_speed_circuit',
      name: 'Agilidad',
      unit: MarkUnit.milliseconds,
      betterDirection: BetterDirection.lower,
    );
    expect(formatAssessmentValue(530123, run), '8:50,123');
    expect(formatAssessmentValue(530100, run), '8:50,1');
    expect(formatAssessmentValue(15430, agility), '15,43 s');
    expect(formatAssessmentDifference(1, MarkUnit.milliseconds), '0,001 s');
    expect(formatAssessmentDifference(120, MarkUnit.milliseconds), '0,12 s');
  });
}

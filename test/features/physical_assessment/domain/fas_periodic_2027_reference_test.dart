import 'dart:convert';

import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/fas_periodic_score_calculator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FasPeriodic2027Reference reference;
  setUpAll(() async {
    reference = await FasPeriodic2027Reference.load();
  });

  test('lee mínimos del anexo II sin reutilizar el baremo de ingreso', () {
    expect(
      FasPeriodic2027Reference.version,
      'es_def_15_2026_periodic_2027_v2_full_scores',
    );
    expect(
      reference
          .passMarkFor(
            testId: 'upper_body_push_ups_2_min',
            category: AssessmentCategory.men,
            age: 25,
          )!
          .threshold,
      14,
    );
    expect(
      reference
          .passMarkFor(
            testId: 'upper_body_push_ups_2_min',
            category: AssessmentCategory.women,
            age: 25,
          )!
          .threshold,
      8,
    );
    expect(
      reference
          .passMarkFor(
            testId: 'run_2000_m',
            category: AssessmentCategory.men,
            age: 30,
          )!
          .threshold,
      714000,
    );
    expect(
      reference
          .passMarkFor(
            testId: 'abdominal_plank',
            category: AssessmentCategory.women,
            age: 60,
          )!
          .threshold,
      28000,
    );
  });

  test('respeta el sentido de cada marca y el límite de edad de agilidad', () {
    final run = reference.passMarkFor(
      testId: 'run_2000_m',
      category: AssessmentCategory.women,
      age: 24,
    )!;
    expect(run.threshold, 754000);
    expect(run.meetsMinimum(754000), isTrue);
    expect(run.meetsMinimum(755000), isFalse);

    final agility = reference.passMarkFor(
      testId: 'agility_speed_circuit',
      category: AssessmentCategory.men,
      age: 44,
    )!;
    expect(agility.threshold, 16200);
    expect(
      reference.passMarkFor(
        testId: 'agility_speed_circuit',
        category: AssessmentCategory.men,
        age: 45,
      ),
      isNull,
    );
  });

  test('calcula puntos exactos y el intervalo conservador entre filas', () {
    expect(
      reference
          .scoreFor(
            testId: 'upper_body_push_ups_2_min',
            category: AssessmentCategory.men,
            age: 25,
            mark: 73,
          )!
          .points,
      100,
    );
    expect(
      reference
          .scoreFor(
            testId: 'upper_body_push_ups_2_min',
            category: AssessmentCategory.men,
            age: 25,
            mark: 14,
          )!
          .points,
      20,
    );
    expect(
      reference
          .scoreFor(
            testId: 'run_2000_m',
            category: AssessmentCategory.men,
            age: 25,
            mark: 706000,
          )!
          .points,
      20,
    );
    expect(
      reference
          .scoreFor(
            testId: 'run_2000_m',
            category: AssessmentCategory.men,
            age: 25,
            mark: 707000,
          )!
          .points,
      19,
    );
  });

  test('aplica columnas por sexo y tramo sin extrapolar', () {
    expect(
      reference
          .scoreFor(
            testId: 'upper_body_push_ups_2_min',
            category: AssessmentCategory.women,
            age: 25,
            mark: 14,
          )!
          .points,
      26,
    );
    expect(
      reference
          .scoreFor(
            testId: 'upper_body_push_ups_2_min',
            category: AssessmentCategory.men,
            age: 26,
            mark: 14,
          )!
          .points,
      21,
    );
    expect(
      reference
          .scoreFor(
            testId: 'run_2000_m',
            category: AssessmentCategory.men,
            age: 25,
            mark: 300000,
          )!
          .points,
      100,
    );
    expect(
      reference
          .scoreFor(
            testId: 'run_2000_m',
            category: AssessmentCategory.men,
            age: 25,
            mark: 1200000,
          )!
          .points,
      0,
    );
  });

  test('elimina centésimas de agilidad y corta al cumplir 45', () {
    final result = reference.scoreFor(
      testId: 'agility_speed_circuit',
      category: AssessmentCategory.men,
      age: 44,
      mark: 16299,
    )!;
    expect(result.scoredMark, 16200);
    expect(result.points, 20);
    expect(
      reference.scoreFor(
        testId: 'agility_speed_circuit',
        category: AssessmentCategory.men,
        age: 45,
        mark: 16200,
      ),
      isNull,
    );
  });

  test(
    'la política histórica conserva el mejor umbral para la misma marca',
    () {
      PeriodicScoreResult score(FasPeriodicScoringPolicy policy) =>
          reference.scoreFor(
            testId: 'run_2000_m',
            category: AssessmentCategory.women,
            age: 60,
            mark: 962000,
            policy: policy,
          )!;
      expect(score(FasPeriodicScoringPolicy.bestThresholdV1).points, 26);
      expect(score(FasPeriodicScoringPolicy.literalRowsV2).points, 0);
      expect(
        score(FasPeriodicScoringPolicy.literalRowsV2).meetsMinimum,
        isFalse,
      );
    },
  );

  test(
    'contrasta todas las celdas, sus intervalos y los objetivos H/M',
    () async {
      final catalog = jsonDecode(
        await rootBundle.loadString(FasPeriodic2027Reference.assetPath),
      ) as Map;
      final ages = {
        for (final band in catalog['ageBands'] as List)
          band['id']: band['minAge'] as int,
      };
      var cells = 0;
      var intervals = 0;
      var targets = 0;
      for (final test in catalog['tests'] as List) {
        final id = test['id'] as String;
        final hasCategories = test['categoriesPerAgeBand'] as bool;
        final bands = (test['ageBands'] as List?) ?? ages.keys.toList();
        final fasterIsBetter = test['betterDirection'] == 'lower';
        final step = switch (id) {
          'agility_speed_circuit' => 100,
          'upper_body_push_ups_2_min' => 1,
          _ => 1000,
        };
        final rows = (test['rows'] as List).cast<List>().toList()
          ..sort(
            (a, b) => fasterIsBetter
                ? (a[0] as int).compareTo(b[0] as int)
                : (b[0] as int).compareTo(a[0] as int),
          );
        for (var band = 0; band < bands.length; band++) {
          final age = ages[bands[band]]!;
          for (final category in AssessmentCategory.values) {
            final col = hasCategories ? band * 2 + category.index : band;
            int points(List row) => (row[1] as List)[col] as int;
            PeriodicScoreResult score(int mark) => reference.scoreFor(
              testId: id,
              category: category,
              age: age,
              mark: mark,
            )!;
            final min = rows.lastWhere((row) => points(row) >= 20)[0] as int;
            final maxPoints = rows.map(points).reduce((a, b) => a > b ? a : b);
            final max =
                rows.lastWhere((row) => points(row) == maxPoints)[0] as int;
            expect(
              reference
                  .passMarkFor(testId: id, category: category, age: age)!
                  .threshold,
              min,
            );
            expect(score(min).meetsMinimum, isTrue);
            expect(
              reference.maximumScoreMarkFor(
                testId: id,
                category: category,
                age: age,
              ),
              max,
            );
            expect(score(max).points, maxPoints);
            targets += 2;
            for (var i = 0; i < rows.length; i++) {
              final mark = rows[i][0] as int;
              final scored = score(mark);
              final detail = '$id $age ${category.name} $mark';
              expect(scored.points, points(rows[i]), reason: detail);
              expect(
                scored.meetsMinimum,
                points(rows[i]) >= 20,
                reason: detail,
              );
              if (hasCategories || category == AssessmentCategory.men) cells++;
              if (id == 'agility_speed_circuit') {
                expect(
                  score(mark + 99).points,
                  points(rows[i]),
                  reason: '$detail +99ms',
                );
              }
              if (i == 0) continue;
              final harder = rows[i - 1];
              final easier = rows[i];
              final first = harder[0] as int;
              final direction = fasterIsBetter ? 1 : -1;
              final expected = points(easier) > points(harder)
                  ? null
                  : points(easier);
              for (
                var between = first + direction * step;
                (between - mark) * direction < 0;
                between += direction * step
              ) {
                expect(
                  score(between).points,
                  expected,
                  reason: '$detail entre filas: $between',
                );
                intervals++;
              }
            }
          }
        }
      }
      expect(cells, 4152);
      expect(targets, 128);
      expect(intervals, greaterThan(9000));
    },
  );

  test('rechaza edades fuera del catálogo', () {
    expect(
      () => reference.passMarkFor(
        testId: 'run_2000_m',
        category: AssessmentCategory.men,
        age: 16,
      ),
      throwsArgumentError,
    );
  });
}

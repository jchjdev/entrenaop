import 'dart:convert';

import 'package:entrenaop/features/physical_assessment/data/repositories/builtin_assessment_reference_repository.dart';
import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_evaluator.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/evaluate_initial_assessment_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/builtin_assessment_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SupabaseClient client(Future<http.Response> Function(http.Request) handler) {
    final c = SupabaseClient(
      'http://localhost',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(handler),
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'consulta preparación y conserva revisión concreta al guardar',
    () async {
      final requests = <Map<String, dynamic>>[];
      final seed = troopRevision();
      final c = client((request) async {
        final params = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(params);
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('builtin_assessment_reference')
                ? {
                    'id': seed.id,
                    'program_id': seed.programId,
                    'status': 'published',
                    'catalog_version': seed.catalogVersion,
                    'scoring_version': seed.scoringVersion,
                    'definition': seed.definition,
                  }
                : 'assessment-1',
          ),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final repo = SupabaseBuiltinAssessmentReferenceRepository(c);
      final reference = await repo.load(
        programId: seed.programId,
        goalId: 'goal-1',
      );
      await repo.record(
        revisionId: reference.id,
        goalId: 'goal-1',
        category: 'men',
        milestone: 'entry',
        marks: {'run_2000_m': 700000},
        completedAt: DateTime.utc(2026, 11, 5),
      );
      expect(requests.first['p_goal_id'], 'goal-1');
      expect(requests.last['p_revision_id'], 'troop-revision-1');
      expect(requests.last['p_marks'], [
        {'test_id': 'run_2000_m', 'value': 700000},
      ]);
      expect(requests.last['p_completed_at'], '2026-11-05T00:00:00.000Z');
    },
  );

  test(
    'un fallo remoto no sustituye la revisión por el catálogo local',
    () async {
      var reads = 0;
      final c = client((request) async {
        reads++;
        return http.Response(
          '{"message":"offline","code":"P0001"}',
          400,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final repo = SupabaseBuiltinAssessmentReferenceRepository(c);
      await expectLater(
        repo.load(programId: 'armed_forces_troop_entry'),
        throwsA(isA<PostgrestException>()),
      );
      expect(reads, 1);
    },
  );

  test('no acepta un borrador ni otra versión histórica devuelta', () async {
    final seed = troopRevision();
    for (final status in ['draft', 'published']) {
      final c = client(
        (request) async => http.Response(
          jsonEncode({
            'id': seed.id,
            'program_id': seed.programId,
            'status': status,
            'catalog_version': seed.catalogVersion,
            'scoring_version': seed.scoringVersion,
            'definition': seed.definition,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      await expectLater(
        SupabaseBuiltinAssessmentReferenceRepository(c)
            .load(programId: seed.programId, scoringVersion: 'otra-version'),
        throwsFormatException,
      );
    }
  });

  test(
    'dos baremos Tropa evalúan sin modificar el primero ni sus unidades',
    () {
      final old = troopRevision().asTroop();
      final next = troopRevision(
        id: 'troop-2',
        version: 'troop-2',
        entryPushUps: 10,
      ).asTroop();
      const evaluate = EvaluateInitialAssessmentUseCase(AssessmentEvaluator());
      final marks = [
        for (final s in old.standards.where(
          (s) =>
              s.category == AssessmentCategory.men &&
              s.milestone == AssessmentMilestone.entry,
        ))
          RecordedMark(
            testId: s.test.id,
            unit: s.test.unit,
            value: s.threshold,
          ),
      ];
      expect(
        evaluate(
          category: AssessmentCategory.men,
          marks: marks,
          reference: old,
        ).passedOverall,
        isTrue,
      );
      expect(
        evaluate(
          category: AssessmentCategory.men,
          marks: marks,
          reference: next,
        ).passedOverall,
        isFalse,
      );
      expect(
        old
            .standardFor(
              testId: 'upper_body_push_ups_2_min',
              category: AssessmentCategory.men,
              milestone: AssessmentMilestone.entry,
            )
            .threshold,
        9,
      );
    },
  );

  test(
    'las referencias FAS publicadas reproducen puntos y décimas de semilla',
    () async {
      final legacy = await FasPeriodic2027Reference.load();
      final published = (await fasRevision()).asFas();
      for (final category in AssessmentCategory.values) {
        for (final age in [17, 25, 26, 40, 44, 45, 59, 60]) {
          for (final (test, marks) in [
            ('upper_body_push_ups_2_min', [0, 8, 14, 30, 73]),
            ('abdominal_plank', [0, 28000, 57000, 160000]),
            ('run_2000_m', [600000, 706000, 914000, 962000, 1006000]),
            ('agility_speed_circuit', [15099, 15100, 16299, 16300]),
          ]) {
            for (final mark in marks) {
              final a = legacy.scoreFor(
                testId: test,
                category: category,
                age: age,
                mark: mark,
              );
              final b = published.scoreFor(
                testId: test,
                category: category,
                age: age,
                mark: mark,
              );
              expect(
                b?.points,
                a?.points,
                reason: '$test/$age/$category/$mark',
              );
              expect(b?.scoredMark, a?.scoredMark);
              expect(b?.meetsMinimum, a?.meetsMinimum);
            }
          }
        }
      }
    },
  );

  test('dos puntuaciones FAS conservan cada versión y su resultado', () async {
    final old = (await fasRevision()).asFas();
    final next = (await fasRevision(
      id: 'fas-2',
      version: 'fas-2',
      pointsFor14PushUps: 21,
    )).asFas();
    int points(FasPeriodic2027Reference r) => r
        .scoreFor(
          testId: 'upper_body_push_ups_2_min',
          category: AssessmentCategory.men,
          age: 25,
          mark: 14,
        )!
        .points;
    expect(points(old), 20);
    expect(points(next), 21);
    expect(points(old), 20);
    expect(old.scoringVersion, 'fas-scoring-1');
    expect(next.scoringVersion, 'fas-2');
  });

  for (final wrong in [false, true]) {
    test(
      'historial usa snapshot coherente y rechaza otra marca: incorrecto $wrong',
      () async {
        final c = client(
          (request) async => http.Response(
            jsonEncode([
              {
                'assessment_id': 'attempt-1',
                'preparation_goal_id': null,
                'catalog_version': 'minimums-2',
                'scoring_version': 'scores-2',
                'completed_at': '2026-11-05T10:00:00Z',
                'category': 'men',
                'age_at_assessment': 25,
                'is_pre_effective_reference': true,
                'test_id': 'agility_speed_circuit',
                'test_name': 'Agilidad',
                'unit': 'milliseconds',
                'value': 16299,
                'threshold': 16200,
                'meets_minimum': true,
                'result_snapshot': {
                  'revision_id': 'revision-2',
                  'catalog_version': 'minimums-2',
                  'scoring_version': 'scores-2',
                  'results': [
                    {
                      'test_id': 'agility_speed_circuit',
                      'mark': wrong ? 17000 : 16299,
                      'scored_mark': 16200,
                      'unit': 'milliseconds',
                      'direction': 'lower',
                      'points': 20,
                    },
                  ],
                },
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        );
        final mark = (await FasPeriodicAssessmentRepository(
          c,
        ).history()).single.marks.single;
        expect(mark.value, 16299);
        expect(mark.points, wrong ? null : 20);
        expect(mark.scoredValue, wrong ? null : 16200);
      },
    );
  }
}

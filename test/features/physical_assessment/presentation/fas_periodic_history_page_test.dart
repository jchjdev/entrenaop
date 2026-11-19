import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/evolution_fixtures.dart';

void main() {
  testWidgets(
    'lee la puntuación guardada y conserva el cálculo sin instantánea',
    (t) async {
      final data = (await t.runAsync(evolutionFasData))!;
      FasPeriodicAssessmentEntry entry(
        String id, {
        int? points,
        String? policy,
      }) => FasPeriodicAssessmentEntry(
        id: id,
        goalId: null,
        scoringVersion: data.fasReference!.scoringVersion,
        scoringPolicy: policy,
        completedAt: DateTime(2026, 11, 19),
        category: 'women',
        age: 60,
        isPreEffectiveReference: true,
        marks: [
          FasPeriodicAssessmentMark(
            testId: 'run_2000_m',
            testName: 'Carrera 2.000 m',
            unit: 'milliseconds',
            value: 962000,
            threshold: 1006000,
            meetsMinimum: points != 0,
            points: points,
          ),
        ],
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FasAssessmentHistoryCard(
                  entry: entry('antiguo'),
                  reference: data.fasReference,
                ),
                FasAssessmentHistoryCard(
                  entry: entry('nuevo', points: 0, policy: 'literal_rows_v2'),
                  reference: data.fasReference,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('26 puntos'), findsOneWidget);
      expect(find.text('0 puntos'), findsOneWidget);
    },
  );

  testWidgets(
    'FAS usa el baremo versionado existente y conserva tests al fallar el refresco',
    (t) async {
      final data = (await t.runAsync(evolutionFasData))!;
      final repository = _Repository(data.fas);
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: FasPeriodicHistoryPage(
            repository: repository,
            reference: data.fasReference,
          ),
        ),
      );
      await t.pumpAndSettle();
      final points = find.textContaining('puntos').first;
      expect(points, findsOneWidget);
      await t.tap(points);
      await t.pumpAndSettle();
      expect(find.text('30 repeticiones'), findsOneWidget);
      repository.fail = true;
      final refresh = t
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await t.pumpAndSettle();
      await refresh;
      expect(find.text('30 repeticiones'), findsOneWidget);
      expect(
        find.text('No se pudieron actualizar los tests. Reintentar.'),
        findsOneWidget,
      );
      repository.fail = false;
      await t.tap(
        find.text('No se pudieron actualizar los tests. Reintentar.'),
      );
      await t.pumpAndSettle();
      expect(repository.calls, 3);
      expect(
        find.text('No se pudieron actualizar los tests. Reintentar.'),
        findsNothing,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('un fallo inicial de FAS permite consultar de nuevo', (t) async {
    final data = (await t.runAsync(evolutionFasData))!;
    final repository = _Repository(data.fas)..fail = true;
    await t.pumpWidget(
      MaterialApp(
        home: FasPeriodicHistoryPage(
          repository: repository,
          reference: data.fasReference,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    repository.fail = false;
    await t.tap(find.text('Reintentar'));
    await t.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

class _Repository implements FasPeriodicAssessmentRepository {
  _Repository(this.rows);
  final List<FasPeriodicAssessmentEntry> rows;
  bool fail = false;
  int calls = 0;
  @override
  Future<List<FasPeriodicAssessmentEntry>> history({String? goalId}) async {
    calls++;
    if (fail) throw StateError('offline');
    return rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

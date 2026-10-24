import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_result_review.dart';
import 'package:workout_editor_ui/workout_result_review_panel.dart';

import '../domain/workout_result_review_test.dart'
    show reviewRow, reviewSession;

void main() {
  testWidgets(
    'comparación oculta RPE no declarado y métricas sin medidas en ambas fechas',
    (tester) async {
      final now = reviewSession([
        reviewRow()..['target_distance_meters'] = 400,
      ]);
      final older = reviewSession(
        [reviewRow()..['target_distance_meters'] = 400],
        id: 'older',
        day: 23,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutSessionComparison(
            current: now,
            loadHistory: (_) async => ReviewHistoryPage([older]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Esfuerzo global'), findsNothing);
      await tester.tap(find.text('Press'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Distancia ·'), findsNothing);
      expect(find.textContaining('Repeticiones · anterior 5'), findsOneWidget);
      expect(find.textContaining('Peso · anterior 20 kg'), findsOneWidget);
    },
  );

  testWidgets(
    'AMRAP compara vueltas y parciales sin convertir la receta en series',
    (tester) async {
      ReviewSession amrap(int rounds, int day, String id) =>
          reviewSessionFromJson({
            'id': id,
            'template_id': 'template',
            'template_version': 1,
            'template_name': 'AMRAP',
            'started_at': DateTime.utc(2026, 10, day).toIso8601String(),
            'status': 'completed',
            'workout_execution_sets': [reviewRow()..['block_format'] = 'amrap'],
            'workout_amrap_results': [
              {
                'block_order': 0,
                'completed_rounds': rounds,
                'partial_item_order': 0,
                'partial_reps': 3,
              },
            ],
          });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutSessionComparison(
            current: amrap(5, 24, 'now'),
            loadHistory: (_) async => ReviewHistoryPage([amrap(4, 23, 'old')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Anterior: 4 vueltas completas'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Actual: 5 vueltas completas'),
        findsOneWidget,
      );
      expect(find.textContaining('Serie 1'), findsNothing);
    },
  );

  testWidgets(
    'control opcional conserva estado explícito y abre comparación bajo demanda',
    (tester) async {
      var filtered = false, loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => WorkoutResultReviewControls(
                session: reviewSession([reviewRow()]),
                onlyDifferences: filtered,
                onFilterChanged: (value) => setState(() => filtered = value),
                loadHistory: (cursor) async {
                  loads++;
                  return const ReviewHistoryPage([]);
                },
              ),
            ),
          ),
        ),
      );
      expect(filtered, isFalse);
      expect(loads, 0);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(filtered, isTrue);
      expect(loads, 0);
      await tester.tap(find.text('Comparar con otra sesión'));
      await tester.pumpAndSettle();
      expect(loads, 1);
      expect(
        find.textContaining('No hay otra sesión anterior'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Cerrar comparación'));
      await tester.pumpAndSettle();
      expect(filtered, isTrue);
    },
  );
  testWidgets(
    'paginación reintentable y comparación conserva datos ausentes a 320 px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var loads = 0;
      final now = reviewSession([reviewRow(actualReps: 7, load: null)]);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: WorkoutSessionComparison(
            current: now,
            loadHistory: (cursor) async {
              loads++;
              if (loads == 1) throw StateError('network');
              if (cursor == null) {
                return const ReviewHistoryPage([], nextCursor: 'page2');
              }
              expect(cursor, 'page2');
              return ReviewHistoryPage([
                reviewSession([reviewRow()], id: 'old', day: 23),
              ]);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reintentar historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reintentar historial'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No hay sesiones comparables en esta página'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Cargar más historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cargar más historial'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Press'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Press'));
      await tester.pumpAndSettle();
      expect(
        find.text('Repeticiones · anterior 5 → actual 7 · Δ +2'),
        findsOneWidget,
      );
      expect(find.text('Peso · anterior 20 kg → actual —'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

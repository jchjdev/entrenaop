import 'dart:convert';
import 'dart:io';

import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/running_context_form_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/performance_reference_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';

import '../../../helpers/performance_visual_review.dart';

Finder _decoration(String label) => find.byWidgetPredicate(
  (w) => w is InputDecorator && w.decoration.labelText == label,
);

void main() {
  setUpAll(loadReviewFont);
  for (final width in [320.0, 390.0, 640.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'referencia a $width px y texto $scale mantiene campos separados y datos con teclado',
        (t) async {
          t.view.physicalSize = Size(width, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.view.resetViewInsets);
          final catalog = StrengthExerciseCatalogCodec.decode(
            jsonDecode(
              File('supabase/catalogs/strength_exercises_v1.json')
                  .readAsStringSync(),
            ),
          ).exercises;
          await t.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('review-boundary'),
              child: MaterialApp(
                theme: EntrenaTheme.dark,
                debugShowCheckedModeBanner: false,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => PerformanceReferenceDialog(
                          data: PreparationTrainingData(
                            catalog: catalog,
                            context: null,
                            runningContext: null,
                            references: const [],
                            objectives: const [],
                            relations: const [],
                            publishedWeeks: const [],
                          ),
                          existing: {
                            'reference': {
                              'goal_code': 'pull_up_assisted_band',
                              'goal_measurement': 'REPS',
                              'reference_kind': 'capacity_test',
                              'targets': [6],
                              'frequency': 1,
                              'task': {
                                'exercise_code': 'pull_up_assisted_band',
                                'measurement': 'REPS',
                                'load_mode': 'assisted',
                                'setup_key': 'Banda roja',
                              },
                            },
                          },
                        ),
                      ),
                      child: const Text('Abrir referencia'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.tap(find.text('Abrir referencia'));
          await t.pumpAndSettle();
          final movement = _decoration('Movimiento que quieres mejorar');
          final measurement = _decoration('Qué quieres mejorar');
          expect(
            t.getTopLeft(measurement).dy - t.getBottomRight(movement).dy,
            greaterThanOrEqualTo(16),
          );
          expect(t.takeException(), isNull);
          if (scale == 1) {
            await capturePerformanceWidget(t, 'referencia-separada-$width');
          }
          await t.tap(find.text('Continuar'));
          await t.pumpAndSettle();
          final series = _decoration('Serie 1 · Repeticiones');
          expect(
            t.getTopLeft(series).dy -
                t.getBottomRight(find.text('Series que has realizado')).dy,
            greaterThanOrEqualTo(16),
          );
          final helper = find.textContaining('Indica la altura del apoyo');
          final paragraph = t.renderObject<RenderParagraph>(helper);
          expect(paragraph.didExceedMaxLines, isFalse);
          t.view.viewInsets = const FakeViewPadding(bottom: 280);
          await t.pumpAndSettle();
          await t.ensureVisible(
            find.widgetWithText(TextFormField, 'Serie 1 · Repeticiones'),
          );
          await t.enterText(
            find.widgetWithText(TextFormField, 'Serie 1 · Repeticiones'),
            '7',
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          if (width == 390 && scale == 1) {
            await capturePerformanceWidget(t, 'referencia-con-teclado');
          }
          t.view.resetViewInsets();
          await t.pumpAndSettle();
          await t.tap(find.text('Continuar'));
          await t.pumpAndSettle();
          expect(find.text('Tu contexto'), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.tap(find.text('Atrás'));
          await t.pumpAndSettle();
          expect(
            t
                .widget<TextFormField>(
                  find.widgetWithText(TextFormField, 'Serie 1 · Repeticiones'),
                )
                .controller!
                .text,
            '7',
          );
        },
      );
    }
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'meta de carrera respeta el selector anterior con texto $scale',
      (t) async {
        t.view.physicalSize = const Size(320, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          MaterialApp(
            theme: EntrenaTheme.dark,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RunningContextFormPage(
              goalId: 'goal',
              goals: const _Goals(),
              loadContext: ({required goalId, required programId}) async =>
                  null,
              loadSharedAvailability: () async => {1: 60, 3: 60},
              saveContext: (_) async {},
            ),
          ),
        );
        await t.pumpAndSettle();
        final goal = find.widgetWithText(
          DropdownButtonFormField<String>,
          'Qué quieres conseguir',
        );
        await t.ensureVisible(goal);
        await t.tap(goal);
        await t.pumpAndSettle();
        await t.tap(find.text('Alcanzar una marca de 2 km').last);
        await t.pumpAndSettle();
        final target = _decoration('Meta de 2 km');
        expect(
          t.getTopLeft(target).dy -
              t.getBottomRight(_decoration('Qué quieres conseguir')).dy,
          greaterThanOrEqualTo(16),
        );
        await t.enterText(
          find.widgetWithText(TextField, 'Meta de 2 km'),
          '7:45',
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }
}

class _Goals implements PreparationGoalRepository {
  const _Goals();
  @override
  Future<List<PreparationGoal>> getActiveGoals() async => const [
    PreparationGoal(
      id: 'goal',
      program: PreparationProgram(
        id: PreparationProgramIds.fasPeriodicAssessment,
        name: 'FAS',
        kind: PreparationProgramKind.internalAssessment,
      ),
    ),
  ];
  @override
  Future<List<PreparationProgram>> getAvailablePrograms() async => [];
  @override
  Future<PreparationGoal> save(PreparationGoal goal) async => goal;
  @override
  Future<void> archive(String goalId) async {}
}

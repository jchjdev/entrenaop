import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/strength_set_fields.dart';
import 'package:workout_editor_ui/running_step_fields.dart';

import '../../../helpers/admin_test_app.dart';
import '../../../../../test/helpers/performance_visual_review.dart';

const _exerciseId = '30000000-0000-4000-8000-000000000001';

class _Workouts extends Fake implements AdminWorkoutRepository {
  CreatePersonalWorkoutInput? saved;
  @override
  Future<List<AdminExercise>> listPublicExercises() async => const [
    AdminExercise(
      id: _exerciseId,
      name: 'Flexiones con apoyo de manos y pausa controlada',
    ),
  ];
  @override
  Future<String> revise(String id, CreatePersonalWorkoutInput input) async {
    saved = input;
    return 'revision-compacto';
  }
}

WorkoutTemplate _template(WorkoutBlockFormat format) {
  final running = format == WorkoutBlockFormat.running;
  final tabata = format == WorkoutBlockFormat.tabata;
  final single = [
    WorkoutBlockFormat.amrap,
    WorkoutBlockFormat.tabata,
  ].contains(format);
  final conventional = format == WorkoutBlockFormat.straightSets;
  final rounds = tabata
      ? 8
      : conventional || running || format == WorkoutBlockFormat.amrap
      ? 1
      : 3;
  final positions = tabata
      ? 8
      : [
          WorkoutBlockFormat.superset,
          WorkoutBlockFormat.circuit,
        ].contains(format)
      ? 2
      : 1;
  return WorkoutTemplate(
    id: 'compacto-original',
    name: running
        ? 'Carrera con recuperaciones'
        : 'Fuerza con objetivos por serie',
    description: 'Mantén el control del movimiento durante todo el recorrido.',
    estimatedDurationMinutes: 30,
    version: 1,
    blocks: [
      WorkoutBlock(
        id: 'block',
        name: 'Trabajo principal',
        format: format,
        rounds: rounds,
        restAfterSeconds: tabata
            ? 10
            : format == WorkoutBlockFormat.emom
            ? 60
            : conventional || running || format == WorkoutBlockFormat.amrap
            ? 0
            : 90,
        timeCapSeconds: format == WorkoutBlockFormat.amrap ? 600 : null,
        items: List.generate(
          positions,
          (position) => WorkoutItem(
            id: 'item-$position',
            exerciseId: running ? runningExerciseId : _exerciseId,
            exerciseName: running ? 'Carrera' : 'Flexiones',
            sets: List.generate(
              single ? 1 : 3,
              (index) => WorkoutSet(
                id: 'set-$position-$index',
                order: index,
                targetReps: running || tabata
                    ? null
                    : index == 1
                    ? 12
                    : 10,
                targetDurationSeconds: tabata ? 20 : null,
                targetDistanceMeters: running ? 400 : null,
                targetLoadKg: running || tabata
                    ? null
                    : index == 1
                    ? 22.5
                    : 20,
                targetRir: running || tabata
                    ? null
                    : index == 1
                    ? 3
                    : 2.5,
                restAfterSeconds: conventional ? 90 : 0,
                targetPaceMinSecondsPerKm: running ? 300 : null,
                targetPaceMaxSecondsPerKm: running ? 320 : null,
                recoveryType: running ? RunningRecoveryType.walking : null,
                recoveryDurationSeconds: running ? 90 : null,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

void main() {
  setUpAll(() => loadReviewFont(always: true));
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]) {
    for (final (format, warmup) in [
      for (final format in [
        WorkoutBlockFormat.straightSets,
        WorkoutBlockFormat.superset,
        WorkoutBlockFormat.circuit,
        WorkoutBlockFormat.intervals,
        WorkoutBlockFormat.tabata,
        WorkoutBlockFormat.emom,
        WorkoutBlockFormat.amrap,
        WorkoutBlockFormat.running,
      ])
        (format, false),
      (WorkoutBlockFormat.straightSets, true),
    ]) {
      testWidgets(
        'ADMIN Compacto ${format.name} calentamiento $warmup a $width/$scale conserva la prescripción al guardar',
        (t) async {
          t.view.physicalSize = Size(width, 950);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final repository = _Workouts();
          final original = _template(format);
          await t.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('review-boundary'),
              child: AdminTestApp(
                theme: EntrenaTheme.dark,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: EntrenaInputPolicy(child: child!),
                ),
                home: AdminWorkoutEditorPage(
                  program: null,
                  repository: repository,
                  originalTemplate: original,
                  revisionId: original.id,
                  warmup: warmup,
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          for (final decorator in t.widgetList<InputDecorator>(
            find.byType(InputDecorator),
          )) {
            final label = decorator.decoration.labelText;
            if (label == null) continue;
            for (final element in find.text(label).evaluate()) {
              final paragraph = t.renderObject<RenderParagraph>(
                find.byWidget(element.widget),
              );
              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason: '$label completo',
              );
            }
          }
          await capturePerformanceWidget(
            t,
            'compacto-admin-${warmup ? 'warmup' : format.name}-${width.toInt()}-$scale-ficha',
          );
          if (format == WorkoutBlockFormat.running) {
            final header = find.byKey(const ValueKey('running-step-header-0'));
            await t.ensureVisible(header);
            await t.pumpAndSettle();
            await t.tap(header);
            await t.pumpAndSettle();
          }
          final fields = format == WorkoutBlockFormat.running
              ? find.byType(RunningStepFields).first
              : format == WorkoutBlockFormat.tabata
              ? find.text('20 s de trabajo · 10 s de recuperación').first
              : find.byType(StrengthSetFields).first;
          await t.scrollUntilVisible(
            fields,
            250,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 100,
          );
          await t.ensureVisible(fields);
          await t.pumpAndSettle();
          final position = t
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          position.jumpTo(
            (position.pixels - 32).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
          await t.pumpAndSettle();
          for (final decorator in t.widgetList<InputDecorator>(
            find.byType(InputDecorator),
          )) {
            final label = decorator.decoration.labelText;
            if (label == null) continue;
            for (final element in find.text(label).evaluate()) {
              final paragraph = t.renderObject<RenderParagraph>(
                find.byWidget(element.widget),
              );
              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason: '$label completo después de desplazar',
              );
            }
          }
          await capturePerformanceWidget(
            t,
            'compacto-admin-${warmup ? 'warmup' : format.name}-${width.toInt()}-$scale-campos',
          );
          final input = find.byType(EditableText).first;
          await t.ensureVisible(input);
          await t.pumpAndSettle();
          await t.tap(input);
          await t.pump();
          expect(t.testTextInput.isVisible, isTrue);
          await t.tapAt(Offset(width - 5, 35));
          await t.pumpAndSettle();
          expect(t.testTextInput.isVisible, isFalse);
          for (final element in find.byType(EditableText).evaluate()) {
            final editor = t
                .state<EditableTextState>(find.byWidget(element.widget))
                .renderEditable;
            if (editor.plainText.length > 12) continue; // Nombres largos admiten edición horizontal; los valores numéricos deben caber.
            final painter = TextPainter(
              text: editor.text,
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.linear(scale),
            )..layout();
            expect(
              painter.width,
              lessThanOrEqualTo(editor.size.width),
              reason: '${editor.plainText} completo',
            );
            painter.dispose();
          }
          final save = find.text(
            warmup ? 'Guardar calentamiento' : 'Guardar revisión como borrador',
          );
          await t.scrollUntilVisible(
            save,
            400,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 100,
          );
          await t.ensureVisible(save);
          await t.pumpAndSettle();
          await t.tap(save);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          final saved = repository.saved!;
          expect(saved.name, original.name);
          expect(saved.description, original.description);
          final block = saved.blocks.single;
          expect(block.format, format);
          expect(block.rounds, original.blocks.single.rounds);
          expect(
            block.restAfterSeconds,
            original.blocks.single.restAfterSeconds,
          );
          expect(block.timeCapSeconds, original.blocks.single.timeCapSeconds);
          expect(block.exercises.length, original.blocks.single.items.length);
          for (var index = 0; index < block.exercises.length; index++) {
            final result = block.exercises[index];
            final source = original.blocks.single.items[index];
            expect(result.exerciseId, source.exerciseId);
            expect(result.sets.length, source.sets.length);
            for (var setIndex = 0; setIndex < result.sets.length; setIndex++) {
              final set = result.sets[setIndex];
              final before = source.sets[setIndex];
              expect(
                set.targetValue,
                before.targetReps ??
                    before.targetDurationSeconds ??
                    before.targetDistanceMeters,
              );
              expect(set.targetLoadKg, before.targetLoadKg);
              expect(set.targetRir, before.targetRir);
              expect(set.restAfterSeconds, before.restAfterSeconds);
              expect(
                set.targetPaceMinSecondsPerKm,
                before.targetPaceMinSecondsPerKm,
              );
              expect(
                set.targetPaceMaxSecondsPerKm,
                before.targetPaceMaxSecondsPerKm,
              );
              expect(set.recoveryType, before.recoveryType);
              expect(
                set.recoveryDurationSeconds,
                before.recoveryDurationSeconds,
              );
            }
          }
        },
      );
    }
  }
}

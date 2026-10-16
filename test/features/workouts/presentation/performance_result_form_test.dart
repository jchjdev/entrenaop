import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/performance_set.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/performance_result_form.dart';

void main() {
  for (final (previous, selection) in <(double?, String?)>[
    (null, '0'),
    (2.5, null),
    (2.5, '3'),
    (2.5, 'No lo sé · Sin registrar'),
  ]) {
    testWidgets(
      'RIR entero, cero y desconocido sin redondear el anterior: $previous → $selection',
      (t) async {
        PerformanceSetResult? saved;
        const p = PerformanceSetPrescription(
          exerciseCode: 'push_up',
          exerciseVersion: 1,
          protocolKey: 'fixture',
          protocolVersion: 1,
          setupKey: 'fixture',
          measurement: 'REPS_IN_TIME',
          fixedDurationSeconds: 60,
          loadMode: 'bodyweight',
          policyVersion: 'v1',
          targetValue: 10,
          targetRir: 3,
          effortMode: 'rir',
        );
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PerformanceResultForm(
                  prescription: p,
                  initialResult: PerformanceSetResult(value: 10, rir: previous),
                  onSave: (r, _) => saved = r,
                ),
              ),
            ),
          ),
        );
        if (selection != null) {
          await t.ensureVisible(
            find.text('Repeticiones que te quedaban · 0 a 10'),
          );
          await t.tap(find.text('Repeticiones que te quedaban · 0 a 10'));
          await t.pumpAndSettle();
          expect(find.widgetWithText(ChoiceChip, '2.5'), findsNothing);
          final option = selection == 'No lo sé · Sin registrar'
              ? find.text(selection)
              : find.widgetWithText(ChoiceChip, selection);
          await t.tap(option);
          await t.pumpAndSettle();
        }
        await t.ensureVisible(find.text('Guardar resultado'));
        await t.tap(find.text('Guardar resultado'));
        await t.pumpAndSettle();
        expect(
          saved?.rir,
          selection == null ? previous : double.tryParse(selection),
        );
      },
    );
  }
  for (final (previous, selection) in <(double?, int?)>[
    (null, 8),
    (7.5, null),
    (7.5, 8),
  ]) {
    testWidgets(
      'RPE entero al elegir y decimal histórico intacto: $previous → $selection',
      (t) async {
        PerformanceSetResult? saved;
        const prescription = PerformanceSetPrescription(
          exerciseCode: 'plank',
          exerciseVersion: 1,
          protocolKey: 'fixture',
          protocolVersion: 1,
          setupKey: 'standard:fixture',
          measurement: 'DURATION',
          loadMode: 'bodyweight',
          policyVersion: 'performance_v2',
          targetValue: 30,
          effortMode: 'rpe',
          targetRpe: 7,
        );
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PerformanceResultForm(
                  prescription: prescription,
                  initialResult: previous == null
                      ? null
                      : PerformanceSetResult(value: 30, rpe: previous),
                  onSave: (r, _) => saved = r,
                ),
              ),
            ),
          ),
        );
        await t.enterText(find.byType(TextFormField).first, '40');
        if (selection != null) {
          final effort = find.text('Esfuerzo que has sentido · 1 a 10');
          await t.ensureVisible(effort);
          await t.tap(effort);
          await t.pumpAndSettle();
          expect(find.widgetWithText(ChoiceChip, '7.5'), findsNothing);
          await t.tap(find.widgetWithText(ChoiceChip, '$selection'));
          await t.pumpAndSettle();
        }
        await t.ensureVisible(find.text('Guardar resultado'));
        await t.tap(find.text('Guardar resultado'));
        await t.pumpAndSettle();
        expect(saved?.value, 40);
        expect(saved?.rpe, selection?.toDouble() ?? previous);
      },
    );
  }
  testWidgets(
    'el reloj propone tiempo medido; confirmar calidad no inventa resultado ni esfuerzo',
    (t) async {
      final elapsed = ValueNotifier<double>(430);
      addTearDown(elapsed.dispose);
      PerformanceSetResult? saved;
      const p = PerformanceSetPrescription(
        exerciseCode: 'plank',
        exerciseVersion: 1,
        protocolKey: 'fixture',
        protocolVersion: 1,
        setupKey: 'standard:fixture',
        measurement: 'DURATION',
        loadMode: 'bodyweight',
        policyVersion: 'performance_v2',
        targetValue: 450,
        effortMode: 'rpe',
        targetRpe: 7,
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PerformanceResultForm(
                prescription: p,
                elapsedSeconds: elapsed,
                onSave: (r, _) => saved = r,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Repeticiones que te quedaban · 0 a 10'), findsNothing);
      await t.tap(find.text('Usar 7:10 del temporizador'));
      expect(
        t
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        '07:10',
      );
      final quality = find.text(
        'Completé la pauta con buena técnica, mismas condiciones y sin molestias',
      );
      await t.ensureVisible(quality);
      await t.tap(quality);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Guardar resultado'));
      await t.tap(find.text('Guardar resultado'));
      expect(saved!.value, 430);
      expect(saved!.rpe, isNull);
      expect(saved!.techniqueValid, isTrue);
      expect(saved!.stopReason, 'none');
    },
  );
  for (final reactive in [false, true]) {
    testWidgets(
      'el circuito ${reactive ? 'reactivo' : 'fijo'} pregunta solo sus datos',
      (t) async {
        PerformanceSetResult? saved;
        final p = PerformanceSetPrescription(
          exerciseCode: reactive
              ? 'reactive_direction_drill'
              : 'slalom_ball_course_16m',
          exerciseVersion: 1,
          protocolKey: 'def_15_2026_agility',
          protocolVersion: 1,
          setupKey: 'standard:fixture',
          measurement: 'TIME_FOR_COURSE',
          loadMode: 'bodyweight',
          policyVersion: 'performance_v1_1',
          targetValue: 13.25,
          recordsStimulusResponses: reactive,
        );
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PerformanceResultForm(
                  prescription: p,
                  onSave: (r, _) => saved = r,
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.text('Respuestas correctas'),
          reactive ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Estímulos recibidos'),
          reactive ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Penalización del protocolo · segundos'),
          findsNothing,
        );
        expect(find.textContaining('standard:'), findsNothing);
        expect(find.textContaining('Montaje:'), findsNothing);
        await t.enterText(find.byType(TextFormField).first, '13,25');
        if (reactive) {
          await t.enterText(find.byType(TextFormField).at(1), '3');
          await t.enterText(find.byType(TextFormField).at(2), '4');
        }
        await t.ensureVisible(find.text('Guardar resultado'));
        await t.tap(find.text('Guardar resultado'));
        await t.pumpAndSettle();
        expect(saved?.value, 13.25);
        expect(saved?.correctResponses, reactive ? 3 : isNull);
        expect(saved?.penaltySeconds, isNull);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('corregir un resultado antiguo conserva sus campos adicionales', (
    t,
  ) async {
    PerformanceSetResult? saved;
    const p = PerformanceSetPrescription(
      exerciseCode: 'slalom_ball_course_16m',
      exerciseVersion: 1,
      protocolKey: 'old',
      protocolVersion: 1,
      setupKey: 'conos y pelota',
      measurement: 'TIME_FOR_COURSE',
      loadMode: 'bodyweight',
      policyVersion: 'performance_v1_1',
      targetValue: 13,
    );
    const old = PerformanceSetResult(
      value: 13,
      penaltySeconds: 0,
      correctResponses: 3,
      totalResponses: 4,
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PerformanceResultForm(
              prescription: p,
              initialResult: old,
              onSave: (r, _) => saved = r,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Guardar resultado'));
    await t.tap(find.text('Guardar resultado'));
    await t.pumpAndSettle();
    expect(saved, old);
  });
  for (final mode in ['REPS', 'DURATION', 'PASS_FAIL', 'REACTIVE_METRICS']) {
    testWidgets('$mode conserva desconocidos y cabe en móvil', (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      PerformanceSetResult? saved;
      final p = PerformanceSetPrescription(
        exerciseCode: 'fixture',
        exerciseVersion: 1,
        protocolKey: 'fixture',
        protocolVersion: 1,
        setupKey: 'suelo',
        measurement: mode,
        loadMode: 'bodyweight',
        policyVersion: 'performance_v1',
        targetValue: 8,
        targetRir: mode == 'REPS' ? 3 : null,
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PerformanceResultForm(
                prescription: p,
                onSave: (r, _) => saved = r,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t
            .widgetList<TextFormField>(find.byType(TextFormField))
            .every((f) => f.controller!.text.isEmpty),
        isTrue,
      );
      if (mode != 'REPS') {
        expect(
          find.text('Repeticiones que te quedaban · 0 a 10'),
          findsNothing,
        );
      }
      final button = find.byType(FilledButton);
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.value, isNull);
      expect(saved!.rir, isNull);
      expect(saved!.techniqueValid, isNull);
      expect(saved!.succeeded, isNull);
      expect(t.takeException(), isNull);
    });
  }
}

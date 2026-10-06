import 'package:entrenaop_admin/features/programs/presentation/admin_performance_execution_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/performance_progression_policy.dart';
import 'package:workout_core/strength_exercise_catalog.dart';
import 'package:workout_core/strength_training_policy.dart' show StrengthTask;

void main() {
  PerformanceProgressionExposure? saved;
  PerformanceProgressionDose dose({bool duration = false, bool load = false}) =>
      PerformanceProgressionDose(
        task: StrengthTask(
          exerciseCode: duration
              ? 'front_plank_forearms'
              : load
              ? 'bench_press_barbell'
              : 'push_up_standard',
          exerciseVersion: 1,
          protocolKey: 'practice',
          protocolVersion: 1,
          setupKey: 'fixed',
          measurement: duration
              ? StrengthMeasurement.duration
              : load
              ? StrengthMeasurement.loadReps
              : StrengthMeasurement.reps,
        ),
        model: duration
            ? PerformanceProgressionModel.duration
            : load
            ? PerformanceProgressionModel.loadAndRepetitions
            : PerformanceProgressionModel.repetitions,
        loadMode: load
            ? StrengthLoadMode.externalLoad
            : StrengthLoadMode.bodyweight,
        targets: [
          duration
              ? 20
              : load
              ? 6
              : 8,
        ],
        restSeconds: 120,
        targetRir: duration ? null : 3,
        loadKg: load ? 40 : null,
      );

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester tester,
    PerformanceProgressionDose prescription, {
    PerformanceProgressionExposure? initial,
  }) async {
    saved = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showDialog<PerformanceProgressionExposure>(
                  context: context,
                  builder: (_) => AdminPerformanceExecutionDialog(
                    id: initial?.id ?? 'record',
                    label: 'Ejercicio',
                    dose: prescription,
                    date: DateTime.now().toUtc().subtract(
                      const Duration(days: 2),
                    ),
                    initial: initial,
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tap(tester, find.text('Abrir'));
  }

  Future<void> choose(WidgetTester tester, String key, String label) async {
    await tap(tester, find.byKey(ValueKey(key)));
    if (find.text(label).evaluate().isEmpty) {
      await tester.drag(find.byType(ListView).last, const Offset(0, 700));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text(label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('un registro vacío conserva ausencias y no copia objetivos', (
    tester,
  ) async {
    final prescription = dose(load: true);
    await mount(tester, prescription);
    await tap(tester, find.text('Guardar registro'));
    expect(saved!.dose, same(prescription));
    expect(saved!.sets.single.validUnits, isNull);
    expect(saved!.sets.single.rir, isNull);
    expect(saved!.sets.single.techniqueValid, isNull);
    expect(saved!.sets.single.actualLoadKg, isNull);
    expect(saved!.tolerated, isNull);
    expect(saved!.conditionsConfirmed, isNull);
    expect(saved!.stop, PerformanceExecutionStop.unknown);
  });

  testWidgets('captura valores reales distintos y conserva la prescripción', (
    tester,
  ) async {
    final prescription = dose(load: true);
    await mount(tester, prescription);
    await tester.enterText(find.byKey(const ValueKey('actual_units_0')), '6');
    await tester.enterText(find.byKey(const ValueKey('actual_load_0')), '35,5');
    await choose(tester, 'technique_0', 'Sí');
    await choose(tester, 'actual_rir_0', '2.5');
    await tap(tester, find.byKey(const ValueKey('execution_conditions')));
    await choose(tester, 'execution_tolerance', 'Sí, tolerable');
    await choose(tester, 'execution_stop', 'Sin interrupción');
    await tap(tester, find.text('Guardar registro'));
    expect(saved!.dose.loadKg, 40);
    expect(saved!.dose.targetRir, 3);
    expect(saved!.sets.single.validUnits, 6);
    expect(saved!.sets.single.actualLoadKg, 35.5);
    expect(saved!.sets.single.rir, 2.5);
    expect(saved!.sets.single.techniqueValid, isTrue);
    expect(saved!.tolerated, isTrue);
    expect(saved!.conditionsConfirmed, isTrue);
    expect(saved!.stop, PerformanceExecutionStop.none);
    expect(tester.takeException(), isNull);
  });

  testWidgets('isometría registra duración sin RIR en pantalla estrecha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, dose(duration: true));
    expect(find.byKey(const ValueKey('actual_rir_0')), findsNothing);
    expect(find.byKey(const ValueKey('actual_load_0')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('actual_units_0')), '18');
    await choose(tester, 'technique_0', 'No');
    await tap(tester, find.text('Guardar registro'));
    expect(saved!.sets.single.validUnits, 18);
    expect(saved!.sets.single.techniqueValid, isFalse);
    expect(saved!.sets.single.rir, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rechaza números inválidos y permite cero realizado', (
    tester,
  ) async {
    await mount(tester, dose(load: true));
    await tester.enterText(find.byKey(const ValueKey('actual_units_0')), '-1');
    await tester.enterText(find.byKey(const ValueKey('actual_load_0')), 'NaN');
    await tap(tester, find.text('Guardar registro'));
    expect(saved, isNull);
    expect(find.text('Introduce un entero entre 0 y 3600.'), findsOneWidget);
    expect(find.text('Introduce kilos mayores que cero.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('actual_units_0')), '0');
    await tester.enterText(find.byKey(const ValueKey('actual_load_0')), '40');
    await tap(tester, find.text('Guardar registro'));
    expect(saved!.sets.single.validUnits, 0);
    expect(saved!.sets.single.rir, isNull);
  });

  testWidgets('seleccionar el día actual no inventa una hora futura', (
    tester,
  ) async {
    final today = DateTime.now().toUtc();
    await mount(tester, dose());
    await tap(
      tester,
      find.widgetWithIcon(OutlinedButton, Icons.calendar_today_outlined),
    );
    await tap(tester, find.text('${today.day}').last);
    await tap(tester, find.text('OK'));
    await tap(tester, find.text('Guardar registro'));
    expect(
      saved!.performedOn,
      DateTime.utc(today.year, today.month, today.day),
    );
    expect(saved!.performedOn.isAfter(DateTime.now().toUtc()), isFalse);
  });

  testWidgets('editar y cancelar no altera el registro anterior', (
    tester,
  ) async {
    final prescription = dose();
    final initial = PerformanceProgressionExposure(
      id: 'previous',
      performedOn: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      dose: prescription,
      sets: [
        PerformanceProgressionSet(validUnits: 7, rir: 4, techniqueValid: true),
      ],
      tolerated: true,
      conditionsConfirmed: true,
    );
    await mount(tester, prescription, initial: initial);
    await tester.enterText(find.byKey(const ValueKey('actual_units_0')), '1');
    await tap(tester, find.text('Cancelar'));
    expect(saved, isNull);
    expect(initial.sets.single.validUnits, 7);
    await tap(tester, find.text('Abrir'));
    await tap(tester, find.text('Guardar registro'));
    expect(saved!.id, initial.id);
    expect(saved!.performedOn, initial.performedOn);
    expect(saved!.dose, same(prescription));
    expect(saved!.sets.single.validUnits, 7);
    expect(saved!.sets.single.rir, 4);
  });
}

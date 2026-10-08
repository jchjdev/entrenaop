// Capturas de widgets actuales con datos ficticios; no consulta cuentas ni red.
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/preparation_marks_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/evolution_fixtures.dart';
import '../test/helpers/measurement_comparison_fixtures.dart';
import '../test/features/physical_assessment/presentation/measurement_comparison_card_test.dart'
    show chooseComparisonValue;
import 'visual_atlas_capture.dart';

void main() {
  atlasSource = 'tools/visual_measurement_comparison_capture.dart';
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]) {
    atlasTestWidgets('Comparación Tropa $width $scale', (t) async {
      await _mount(t, comparisonMarksData(), width: width, scale: scale);
      await atlasSettle(t); // 1: resultados y acceso
      await t.tap(find.text('Comparar marcas'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Comparar marcas'));
      await atlasSettle(t); // 2: selector
      await t.ensureVisible(find.text('Mejora de 2 rep'));
      await atlasSettle(t); // 3: comparación
      await chooseComparisonValue(
        t,
        'Prueba',
        'Control de 2 km · Control de carrera',
      );
      await t.ensureVisible(find.text('Mejora de 20 s'));
      await atlasSettle(t); // 4: control y RPE
      expect(t.takeException(), isNull);
    });
  }

  atlasTestWidgets('Comparación FAS', (t) async {
    final saved = (await t.runAsync(evolutionFasData))!;
    final current = saved.fas.single;
    final data = PreparationMarksData(
      goal: saved.goal,
      fasReference: saved.fasReference,
      fas: [
        current,
        FasPeriodicAssessmentEntry(
          id: 'older',
          goalId: current.goalId,
          scoringVersion: current.scoringVersion,
          completedAt: DateTime(2026, 9, 20),
          category: current.category,
          age: 29,
          isPreEffectiveReference: true,
          marks: [
            FasPeriodicAssessmentMark(
              testId: current.marks.single.testId,
              testName: current.marks.single.testName,
              unit: 'repetitions',
              value: 26,
              threshold: 18,
              meetsMinimum: true,
            ),
          ],
        ),
      ],
    );
    await _mount(t, data);
    await atlasSettle(t); // 1: resultados
    await t.tap(find.text('Comparar marcas'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Mejora de 4 rep'));
    await atlasSettle(t); // 2: comparación de marcas, edades distintas
    await t.ensureVisible(find.text('Baremo FAS 2027').first);
    await t.pumpAndSettle();
    await t.tap(
      find.byKey(const PageStorageKey('fas-assessment-fas-assessment')),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('30 repeticiones'));
    await atlasSettle(t); // 3: puntos originales, sin trasladarlos
    expect(t.takeException(), isNull);
  });

  atlasTestWidgets('Comparación versiones distintas', (t) async {
    await _mount(
      t,
      PreparationMarksData(
        goal: evolutionTroop,
        troop: [
          comparisonAssessment(),
          comparisonAssessment(day: 1, version: 'ingreso-v2'),
        ],
      ),
    );
    await atlasSettle(t); // 1: resultados
    await t.tap(find.text('Comparar marcas'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.textContaining('Necesitas otra medición'));
    await atlasSettle(t); // 2: no fabrica una comparación
    expect(t.takeException(), isNull);
  });

  atlasTestWidgets('Comparación programa sin contrato', (t) async {
    await _mount(t, evolutionGenericData());
    await atlasSettle(t); // 1: motivo y evaluación
    await t.ensureVisible(find.text('22/09/2026 · Apto'));
    await t.pumpAndSettle();
    await t.tap(find.text('22/09/2026 · Apto'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('47,5 puntos totales'));
    await atlasSettle(t); // 2: conserva snapshot e intentos
    expect(t.takeException(), isNull);
  });
}

Future<void> _mount(
  WidgetTester t,
  PreparationMarksData data, {
  double width = 390,
  double scale = 1,
}) async {
  t.view.physicalSize = Size(width, 1050);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await atlasPumpWidget(
    t,
    MaterialApp(
      theme: EntrenaTheme.dark,
      debugShowCheckedModeBanner: false,
      builder: (_, child) => MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1050),
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: PreparationMarksPage(
        goalId: data.goal.id!,
        load: (_) async => data,
      ),
    ),
  );
  await t.pumpAndSettle();
}

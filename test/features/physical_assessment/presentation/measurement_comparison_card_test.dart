import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/preparation_marks_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/preparation_measurement_history.dart';
import 'package:entrenaop/features/physical_assessment/presentation/widgets/measurement_comparison_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/measurement_comparison_fixtures.dart';

void main() {
  Future<void> mount(
    WidgetTester t, {
    double width = 390,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final data = comparisonMarksData();
    await t.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MeasurementComparisonCard(
              series: preparationMeasurementHistory(
                troop: data.troop,
                running: data.running,
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Comparar marcas'));
    await t.pumpAndSettle();
  }

  testWidgets(
    'elige prueba y fechas y evita comparar con una fecha posterior',
    (t) async {
      await mount(t);
      expect(find.text('Mejora de 2 rep'), findsOneWidget);
      await chooseComparisonValue(t, 'Comparar con', '01/10/2026 · 09:00');
      expect(find.text('Mejora de 6 rep'), findsOneWidget);
      await chooseComparisonValue(t, 'Fecha reciente', '03/10/2026 · 09:00');
      expect(find.text('Mejora de 4 rep'), findsOneWidget);
      await chooseComparisonValue(t, 'Fecha reciente', '01/10/2026 · 09:00');
      expect(find.text('Comparar con'), findsNothing);
      expect(
        find.textContaining('Elige una fecha reciente que tenga'),
        findsOneWidget,
      );
      await chooseComparisonValue(t, 'Fecha reciente', '06/10/2026 · 09:00');
      expect(find.text('Mejora de 2 rep'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'tiempos menores mejoran, plancha mantenida y controles conservan RPE',
    (t) async {
      await mount(t);
      await chooseComparisonValue(
        t,
        'Prueba',
        'Carrera de 2 km · Evaluación · Ingreso · H',
      );
      expect(find.text('Mejora de 20 s'), findsOneWidget);
      await chooseComparisonValue(t, 'Fecha reciente', '03/10/2026 · 09:00');
      expect(find.text('Retroceso de 10 s'), findsOneWidget);
      await chooseComparisonValue(
        t,
        'Prueba',
        'Plancha isométrica · Evaluación · Ingreso · H',
      );
      expect(find.text('Marca mantenida'), findsOneWidget);
      await chooseComparisonValue(
        t,
        'Prueba',
        'Control de 2 km · Control de carrera',
      );
      expect(find.text('Mejora de 20 s'), findsOneWidget);
      expect(find.text('RPE 8'), findsOneWidget);
      expect(find.text('RPE 7'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'recargar y fallar conserva selección y comparación, incluso con un resultado nuevo',
    (t) async {
      var calls = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: PreparationMarksPage(
            goalId: 'troop',
            load: (_) async {
              if (++calls == 2) throw StateError('offline');
              return comparisonMarksData(newResult: calls > 2);
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Comparar marcas'));
      await t.pumpAndSettle();
      await chooseComparisonValue(t, 'Comparar con', '01/10/2026 · 09:00');
      final historical = find.byKey(const ValueKey('troop-assessment-6'));
      await t.ensureVisible(historical);
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(of: historical, matching: find.byType(ExpansionTile)),
      );
      await t.pumpAndSettle();
      expect(
        find.descendant(of: historical, matching: find.text('24 rep')),
        findsOneWidget,
      );
      final refresh = t
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await t.pumpAndSettle();
      await refresh;
      expect(find.text('Mejora de 6 rep'), findsOneWidget);
      await t.ensureVisible(find.text('Reintentar actualizar'));
      await t.pumpAndSettle();
      await t.tap(find.text('Reintentar actualizar'));
      await t.pumpAndSettle();
      expect(calls, 3);
      expect(find.text('Mejora de 6 rep'), findsOneWidget);
      expect(find.text('Reintentar actualizar'), findsNothing);
      expect(
        find.descendant(of: historical, matching: find.text('24 rep')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 1100.0]) {
    testWidgets('comparación y selectores legibles en $width px con texto 2x', (
      t,
    ) async {
      await mount(t, width: width, scale: 2);
      await chooseComparisonValue(
        t,
        'Prueba',
        'Control de 2 km · Control de carrera',
      );
      await t.ensureVisible(find.text('Mejora de 20 s'));
      await t.pumpAndSettle();
      expect(find.text('Mejora de 20 s'), findsOneWidget);
      for (final label in ['Prueba', 'Fecha reciente', 'Comparar con']) {
        final field = find.ancestor(
          of: find.text(label),
          matching: find.byType(DropdownButtonFormField<String>),
        );
        final selectedText = find.descendant(
          of: field,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('selected-'),
          ),
        );
        final paragraph = t.renderObject<RenderParagraph>(selectedText);
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
        )..layout(maxWidth: paragraph.size.width);
        expect(
          paragraph.size.height,
          greaterThanOrEqualTo(painter.height - .01),
          reason: '$label debe mostrar todas sus líneas',
        );
        expect(
          t.getRect(selectedText).bottom,
          lessThanOrEqualTo(t.getRect(field).bottom),
          reason: '$label no debe recortarse dentro del campo',
        );
        painter.dispose();
      }
      expect(t.takeException(), isNull);
    });
  }
}

Future<void> chooseComparisonValue(
  WidgetTester t,
  String label,
  String text,
) async {
  final field = find.ancestor(
    of: find.text(label),
    matching: find.byType(DropdownButtonFormField<String>),
  );
  await t.ensureVisible(field);
  await t.pumpAndSettle();
  await t.tap(field);
  await t.pumpAndSettle();
  if (find.text(text).evaluate().isEmpty) {
    await t.scrollUntilVisible(
      find.text(text),
      160,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 20,
    );
    await t.pumpAndSettle();
  }
  await t.ensureVisible(find.text(text).last);
  await t.pumpAndSettle();
  await t.tap(find.text(text).last);
  await t.pumpAndSettle();
}

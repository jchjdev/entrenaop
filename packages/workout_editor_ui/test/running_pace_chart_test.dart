import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/running_pace_analysis.dart';
import 'package:workout_editor_ui/running_pace_chart.dart';

Map<String, dynamic> row(
  int i, {
  String? kind = 'run',
  num? distance = 400,
  num? time = 87.32,
  int recovery = 50,
  String status = 'completed',
}) => {
  'id': '$i',
  'block_order': 0,
  'item_order': 0,
  'set_order': i,
  'block_name': 'Series de 400',
  'block_format': 'running',
  'status': status,
  'exercise_name': 'Carrera',
  'exercise_id': 'run',
  'actual_distance_meters': distance,
  'actual_duration_seconds': 90,
  'observed_duration_seconds': time,
  'result_source': 'device',
  'target_distance_meters': distance,
  'target_pace_min_seconds_per_km': 215,
  'target_pace_max_seconds_per_km': 220,
  'recovery_duration_seconds': recovery,
  'recovery_type': 'passive',
  'actual_recovery_duration_seconds': 50,
  'actual_recovery_distance_meters': 42.66,
  'actual_rpe': 8,
  if (kind != null)
    'running_step': {
      'schema_version': 2,
      'kind': kind,
      'completion': 'distance',
    },
};

List<Map<String, dynamic>> example() => [
  row(0, kind: 'warmup', distance: 2000, time: 840),
  row(1),
  row(2, time: 88.28),
  row(3, time: 87.14),
  row(4, kind: 'cooldown', distance: 1000, time: 420),
];

Widget app(
  List<Map<String, dynamic>> rows, {
  bool light = false,
  double scale = 1,
}) => MaterialApp(
  theme: light ? EntrenaTheme.light : EntrenaTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: RunningPaceChart(
        key: const ValueKey('chart'),
        analysis: RunningPaceAnalysis.fromRows(rows),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'muestra esfuerzos por defecto y permite consultar todas las fases',
    (t) async {
      await t.pumpWidget(app(example()));
      expect(find.text('Ritmo por serie'), findsOneWidget);
      expect(find.byKey(const ValueKey('pace-point-3')), findsNothing);
      expect(find.text('3 de 3'), findsOneWidget);
      await t.tap(find.text('Todos los tramos'));
      await t.pumpAndSettle();
      expect(find.text('Ritmo por tramo'), findsOneWidget);
      expect(find.byKey(const ValueKey('pace-point-4')), findsOneWidget);
      expect(find.text('5 de 5'), findsOneWidget);
    },
  );

  testWidgets('tooltip y toque muestran objetivo, medida, recuperación y RPE', (
    t,
  ) async {
    await t.pumpWidget(app(example()));
    final tooltip = t
        .widgetList<Tooltip>(find.byType(Tooltip))
        .firstWhere((w) => w.message?.startsWith('Serie 1') ?? false);
    expect(tooltip.message, contains('Ritmo realizado: 3:38/km'));
    expect(tooltip.message, contains('Objetivo: 3:35–3:40/km'));
    expect(tooltip.message, contains('Tiempo realizado: 1:27.32'));
    await t.tap(find.byKey(const ValueKey('pace-point-0')));
    await t.pumpAndSettle();
    expect(find.textContaining('Distancia realizada: 400 m'), findsOneWidget);
    expect(find.textContaining('Recuperación realizada: 0:50'), findsOneWidget);
    expect(find.text('Esfuerzo percibido: 8 RPE'), findsOneWidget);
    await t.tap(find.byTooltip('Cerrar detalle del tramo'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Cerrar detalle del tramo'), findsNothing);
  });

  testWidgets(
    'las repeticiones omitidas conservan posición y detalle sin ritmo inventado',
    (t) async {
      await t.pumpWidget(app([row(0), row(1, status: 'skipped'), row(2)]));
      expect(find.text('2 de 3'), findsOneWidget);
      expect(
        find.textContaining('Los huecos conservan la posición'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('pace-point-1')));
      await t.pumpAndSettle();
      expect(find.text('Tramo omitido'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.textContaining('Sin ritmo registrado'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Ritmo realizado:'), findsNothing);
    },
  );

  testWidgets('sin medidas no dibuja una curva ni estadísticas ficticias', (
    t,
  ) async {
    await t.pumpWidget(app([row(0, distance: null)]));
    expect(
      find.textContaining('Todavía no hay tramos completados'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pace-horizontal-scroll')), findsNothing);
    expect(find.text('Ritmo medio'), findsNothing);
  });

  testWidgets(
    'registros sin fases se consultan completos y no entran a regularidad',
    (t) async {
      await t.pumpWidget(app([row(0, kind: null), row(1, kind: null)]));
      expect(find.text('Ritmo por tramo'), findsOneWidget);
      expect(
        find.textContaining('Estos registros no distinguen las fases'),
        findsOneWidget,
      );
      expect(
        t
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Series'))
            .onSelected,
        isNull,
      );
      expect(find.textContaining('Disponible con dos o más'), findsOneWidget);
    },
  );

  testWidgets('selección accesible por teclado abre el mismo detalle', (
    t,
  ) async {
    await t.pumpWidget(app(example()));
    final point = find.byKey(const ValueKey('pace-point-0'));
    final label = find.descendant(of: point, matching: find.text('1'));
    Focus.of(t.element(label)).requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.byTooltip('Cerrar detalle del tramo'), findsOneWidget);
  });

  testWidgets(
    'las correcciones de una ejecución actualizan los datos de consulta',
    (t) async {
      await t.pumpWidget(app([row(0), row(1)]));
      expect(find.text('3:38/km'), findsWidgets);
      await t.pumpWidget(app([row(0, time: 100), row(1, time: 100)]));
      await t.pumpAndSettle();
      expect(find.text('4:10/km'), findsWidgets);
      expect(find.text('3:38/km'), findsNothing);
    },
  );

  for (final width in [320.0, 1200.0]) {
    for (final light in [false, true]) {
      testWidgets(
        'legible a $width / claro $light con texto doble y dos grupos',
        (t) async {
          t.view.physicalSize = Size(width, 1400);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          await t.pumpWidget(
            app(
              [row(0), row(1), row(2, recovery: 60), row(3, recovery: 60)],
              light: light,
              scale: 2,
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          final dropdown = find.byType(DropdownButtonFormField<String>);
          await t.ensureVisible(dropdown);
          await t.tap(dropdown);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await t.pumpAndSettle();
          await t.ensureVisible(find.byKey(const ValueKey('pace-point-0')));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const ValueKey('pace-point-0')));
          await t.pumpAndSettle();
          expect(find.byTooltip('Cerrar detalle del tramo'), findsOneWidget);
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}

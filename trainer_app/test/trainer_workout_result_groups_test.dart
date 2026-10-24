import 'package:entrenaop_trainer/trainer_workout_result.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> series(
  int order, {
  int block = 0,
  int item = 0,
  String exercise = 'bench',
  String name = 'Press banca',
  String format = 'straight_sets',
  String status = 'completed',
  int reps = 5,
  num? load = 20,
}) => {
  'block_order': block,
  'block_name': 'Bloque ${block + 1}',
  'item_order': item,
  'exercise_id': exercise,
  'exercise_name': name,
  'block_format': format,
  'set_order': order,
  'target_reps': 5,
  'target_load_kg': 20,
  'rest_after_seconds': 60,
  'status': status,
  'actual_reps': status == 'completed' ? reps : null,
  'actual_load_kg': status == 'completed' ? load : null,
  'result_source': 'device',
  'observed_duration_seconds': 4.665 + order,
};

Widget resultApp(List<Map<String, dynamic>> sets, {double scale = 1}) =>
    MaterialApp(
      theme: EntrenaTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: TrainerWorkoutResultContent(
          result: {
            'template_name': 'Fuerza de prueba',
            'template_version': 1,
            'status': 'completed',
            'workout_execution_sets': sets,
            'workout_amrap_results': <Map>[],
          },
        ),
      ),
    );

void main() {
  testWidgets(
    'diez series ocupan una tarjeta y mantienen su detalle original',
    (tester) async {
      final sets = List.generate(10, (i) => series(i));
      await tester.pumpWidget(resultApp(sets));
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(find.text('Press banca'), findsOneWidget);
      expect(find.text('10/10 completadas'), findsOneWidget);
      expect(find.text('Realizado: 10 × 5 rep · 20 kg'), findsOneWidget);
      expect(find.textContaining('Pautado:'), findsNothing);
      await tester.tap(find.text('Press banca'));
      await tester.pumpAndSettle();
      expect(find.text('Serie 1 · Completada'), findsOneWidget);
      expect(
        find.textContaining('Realizado: 5 rep · 20 kg · 0:04.67'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Serie 10 · Completada'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Serie 10 · Completada'), findsOneWidget);
      expect(sets.first['observed_duration_seconds'], 4.665);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no mezcla el mismo ejercicio de otra posición o bloque', (
    tester,
  ) async {
    await tester.pumpWidget(
      resultApp([
        series(0),
        series(1),
        series(0, item: 1),
        series(0, block: 1),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(3));
    expect(find.text('Bloque 1'), findsOneWidget);
    expect(find.text('Bloque 2'), findsOneWidget);
    expect(find.text('2/2 completadas'), findsOneWidget);
    expect(find.text('1/1 completadas'), findsNWidgets(2));
  });

  testWidgets(
    'el nombre no agrupa ejercicios distintos ni posiciones sin identidad',
    (tester) async {
      final legacy = series(0)..remove('item_order');
      await tester.pumpWidget(
        resultApp([series(0), series(1, exercise: 'another'), legacy]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsNWidgets(3));
    },
  );

  testWidgets(
    'excepciones, omisiones y kilos ausentes no se resumen como pauta cumplida',
    (tester) async {
      await tester.pumpWidget(
        resultApp([
          series(0, reps: 4),
          series(1, reps: 3, load: null),
          series(2, status: 'skipped'),
          series(3, status: 'pending'),
        ]),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('2/4 completadas · 1 omitida · 1 pendiente'),
        findsOneWidget,
      );
      expect(find.text('Resultados variables · ver series'), findsOneWidget);
      expect(find.textContaining('4 × 5 rep'), findsNothing);
      await tester.tap(find.text('Press banca'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Realizado: 4 rep · 20 kg'), findsOneWidget);
      expect(find.textContaining('Realizado: 3 rep · 0:05.67'), findsOneWidget);
      expect(find.text('Serie 3 · Omitida'), findsOneWidget);
      expect(find.text('Serie 4 · Pendiente'), findsOneWidget);
      expect(find.textContaining('Pautado: 5 rep · 20 kg'), findsNWidgets(4));
    },
  );

  testWidgets('carrera conserva tramos independientes dentro del bloque', (
    tester,
  ) async {
    await tester.pumpWidget(
      resultApp([series(0, format: 'running'), series(1, format: 'running')]),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Tramo 1 · Completada'), findsOneWidget);
    expect(find.text('Tramo 2 · Completada'), findsOneWidget);
  });

  for (final width in [320.0, 1200.0]) {
    testWidgets('superserie plegable a $width con texto ampliado', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sets = [
        for (var item = 0; item < 2; item++)
          for (var i = 0; i < 3; i++)
            series(
              i,
              item: item,
              exercise: '$item',
              format: 'superset',
              name: 'Ejercicio ${item + 1} con un nombre largo de catálogo',
            ),
      ];
      await tester.pumpWidget(resultApp(sets, scale: 2));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Superserie'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Superserie'), findsOneWidget);
      final title = find.text('Ejercicio 1 con un nombre largo de catálogo');
      await tester.scrollUntilVisible(
        title,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Serie 3 · Completada'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Ejercicio 2 con un nombre largo de catálogo'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Ejercicio 2 con un nombre largo de catálogo'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

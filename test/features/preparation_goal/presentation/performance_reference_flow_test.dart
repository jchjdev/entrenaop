import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:entrenaop/core/presentation/app_dates.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/performance_reference_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';

PreparationTrainingData _data() => PreparationTrainingData(
  catalog: [
    for (final file in [
      'strength_exercises_v1.json',
      'performance_exercises_v2.json',
    ])
      for (final row
          in jsonDecode(
                File('supabase/catalogs/$file').readAsStringSync(),
              )['exercises']
              as List)
        StrengthExerciseCatalogCodec.decodeDefinition(
          Map<String, dynamic>.from(row as Map),
        ),
  ],
  context: null,
  runningContext: null,
  references: const [],
  objectives: const [],
  relations: const [],
  publishedWeeks: const [],
);

class _Capture {
  int saves = 0;
  PerformanceReferenceInput? saved, result;
  ModalRoute<dynamic>? dialogRoute;
}

Future<_Capture> _mount(
  WidgetTester tester, {
  Map<String, dynamic>? existing,
  double width = 390,
  Future<void> Function(PerformanceReferenceInput)? onSave,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final capture = _Capture();
  final data = _data();
  await tester.pumpWidget(
    MaterialApp(
      theme: EntrenaTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              capture.result = await showDialog<PerformanceReferenceInput>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) {
                  capture.dialogRoute = ModalRoute.of(dialogContext);
                  return PerformanceReferenceDialog(
                    data: data,
                    existing: existing,
                    objective: const {
                      'name': 'Circuito',
                      'profile_code': 'slalom_ball_course_16m',
                      'measurement': 'TIME_FOR_COURSE',
                      'protocol_key': 'course_test',
                      'protocol_version': 1,
                      'parameters': <String, dynamic>{},
                    },
                    onSave: (input) async {
                      capture.saves++;
                      await onSave?.call(input);
                      capture.saved = input;
                    },
                  );
                },
              );
            },
            child: const Text('Abrir referencia'),
          ),
        ),
      ),
    ),
  );
  await _tap(tester, 'Abrir referencia');
  return capture;
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _kind(WidgetTester tester, String label) async {
  final dropdown = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration.labelText == 'Qué estás registrando',
  );
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);
Future<void> _enter(WidgetTester tester, String label, String value) async {
  final finder = _field(label);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

Future<void> _confirmContext(WidgetTester tester) async {
  for (final element in find.byType(CheckboxListTile).evaluate().toList()) {
    final finder = find.byWidget(element.widget);
    if ((element.widget as CheckboxListTile).value != true) {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }
  }
}

Future<void> _oneSeriesToContext(WidgetTester tester) async {
  await _kind(tester, 'Una serie de entrenamiento');
  await _tap(tester, 'Continuar');
  await _enter(tester, 'Serie 1 · Tiempo de circuito', '12.5');
  await _tap(tester, 'Continuar');
  await _confirmContext(tester);
}

void main() {
  for (final rest in [(29, '29'), (30, '30'), (600, '10:00'), (601, '10:01')]) {
    testWidgets('el descanso ${rest.$1}s se valida en el paso de resultados', (
      tester,
    ) async {
      final capture = await _mount(tester);
      await _kind(tester, 'Varias series del mismo entrenamiento');
      await _tap(tester, 'Continuar');
      await _enter(tester, 'Serie 1 · Tiempo de circuito', '12.5');
      await _enter(tester, 'Serie 2 · Tiempo de circuito', '13.5');
      await _enter(tester, 'Descanso entre series', rest.$2);
      await _tap(tester, 'Continuar');
      if (rest.$1 == 29 || rest.$1 == 601) {
        expect(find.text('Tu resultado real'), findsOneWidget);
        expect(
          find.text('Indica un descanso entre 00:30 y 10:00.'),
          findsOneWidget,
        );
        expect(capture.saves, 0);
      } else {
        expect(find.text('Tu contexto'), findsOneWidget);
        await _confirmContext(tester);
        await _tap(tester, 'Guardar referencia');
        expect(capture.result!.reference['rest_seconds'], rest.$1);
        expect(capture.result!.reference['targets'], [12.5, 13.5]);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final keepRepeated in [false, true]) {
    testWidgets(
      'cambiar tipo conserva series y guarda solo las elegidas: $keepRepeated',
      (tester) async {
        final capture = await _mount(tester);
        await _kind(tester, 'Varias series del mismo entrenamiento');
        await _tap(tester, 'Continuar');
        await _enter(tester, 'Serie 1 · Tiempo de circuito', '12.5');
        await _enter(tester, 'Serie 2 · Tiempo de circuito', '13.5');
        await _enter(tester, 'Descanso entre series', '100');
        await _tap(tester, 'Atrás');
        await _kind(tester, 'Una serie de entrenamiento');
        await _kind(tester, 'Varias series del mismo entrenamiento');
        await _tap(tester, 'Continuar');
        expect(
          tester
              .widget<TextFormField>(_field('Serie 2 · Tiempo de circuito'))
              .controller!
              .text,
          '00:13.5',
        );
        if (!keepRepeated) {
          await _tap(tester, 'Atrás');
          await _kind(tester, 'Una serie de entrenamiento');
          await _tap(tester, 'Continuar');
        }
        await _tap(tester, 'Continuar');
        await _confirmContext(tester);
        await _tap(tester, 'Guardar referencia');
        expect(
          capture.result!.reference['targets'],
          keepRepeated ? [12.5, 13.5] : [12.5],
        );
        expect(
          capture.result!.reference['rest_seconds'],
          keepRepeated ? 60 : 0,
        );
      },
    );
  }

  for (final step in [0, 1, 2]) {
    testWidgets(
      'cerrar con X protege los cambios de referencia en paso ${step + 1}',
      (tester) async {
        final capture = await _mount(tester);
        await _kind(tester, 'Una serie de entrenamiento');
        if (step > 0) {
          await _tap(tester, 'Continuar');
          await _enter(tester, 'Serie 1 · Tiempo de circuito', '12.5');
        }
        if (step > 1) await _tap(tester, 'Continuar');
        await tester.tap(find.byTooltip('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.text('¿Salir sin guardar la referencia?'), findsOneWidget);
        await _tap(tester, 'Continuar');
        expect(find.text('Paso ${step + 1} de 3'), findsOneWidget);
        if (step == 1) {
          expect(
            tester
                .widget<TextFormField>(_field('Serie 1 · Tiempo de circuito'))
                .controller!
                .text,
            '00:12.5',
          );
        }
        await tester.tap(find.byTooltip('Cancelar'));
        await tester.pumpAndSettle();
        await _tap(tester, 'Salir sin guardar');
        expect(find.byType(PerformanceReferenceDialog), findsNothing);
        expect(capture.saves, 0);
        expect(capture.result, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'atrás del sistema protege cambios y Cancelar de escritorio usa la misma guarda',
    (tester) async {
      await _mount(tester, width: 800);
      await _kind(tester, 'Una serie de entrenamiento');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin guardar la referencia?'), findsOneWidget);
      await _tap(tester, 'Continuar');
      await _tap(tester, 'Cancelar');
      expect(find.text('¿Salir sin guardar la referencia?'), findsOneWidget);
      await _tap(tester, 'Salir sin guardar');
      expect(find.byType(PerformanceReferenceDialog), findsNothing);
    },
  );

  for (final existing in [false, true]) {
    testWidgets(
      'cancelar sin editar no pregunta; referencia existente=$existing',
      (tester) async {
        final before = {
          'goal_code': 'slalom_ball_course_16m',
          'goal_measurement': 'TIME_FOR_COURSE',
          'reference_kind': 'performed_set',
          'targets': [12.5],
          'observed_on': '2026-11-03',
          'frequency': 1,
          'task': {
            'exercise_code': 'slalom_ball_course_16m',
            'measurement': 'TIME_FOR_COURSE',
          },
        };
        final snapshot = jsonEncode(before);
        final capture = await _mount(
          tester,
          existing: existing ? {'reference': before} : null,
        );
        await tester.tap(find.byTooltip('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.byType(PerformanceReferenceDialog), findsNothing);
        expect(find.text('¿Salir sin guardar la referencia?'), findsNothing);
        expect(capture.saves, 0);
        expect(jsonEncode(before), snapshot);
      },
    );
  }

  testWidgets(
    'un error de datos explica el problema y permite reintentar sin perder la referencia',
    (tester) async {
      var attempts = 0;
      final capture = await _mount(
        tester,
        onSave: (_) async {
          if (++attempts == 1) {
            throw const PreparationTrainingException(
              'Revisa la fecha de la referencia.',
            );
          }
        },
      );
      await _oneSeriesToContext(tester);
      expect(
        find.text('Realizado el ${formatAppDate(DateTime.now())}'),
        findsOneWidget,
      );
      await _tap(tester, 'Guardar referencia');
      expect(
        find.text('Revisa la fecha de la referencia. Tus datos siguen aquí.'),
        findsOneWidget,
      );
      expect(find.textContaining('revisa la conexión'), findsNothing);
      await _tap(tester, 'Atrás');
      expect(
        tester
            .widget<TextFormField>(_field('Serie 1 · Tiempo de circuito'))
            .controller!
            .text,
        '00:12.5',
      );
      await _tap(tester, 'Continuar');
      await _tap(tester, 'Guardar referencia');
      expect(capture.result!.reference['targets'], [12.5]);
      expect(capture.saves, 2);
    },
  );

  testWidgets(
    'guardar bloquea salir y la confirmación cierra con el resultado una sola vez',
    (tester) async {
      final gate = Completer<void>();
      final capture = await _mount(tester, onSave: (_) => gate.future);
      await _oneSeriesToContext(tester);
      await _tap(tester, 'Guardar referencia');
      expect(find.text('Guardando…'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PerformanceReferenceDialog), findsOneWidget);
      expect(find.text('¿Salir sin guardar la referencia?'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(PerformanceReferenceDialog), findsNothing);
      expect(capture.result!.reference['targets'], [12.5]);
      expect(capture.saves, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cambiar solo frecuencia también protege una referencia existente al volver',
    (tester) async {
      await _mount(
        tester,
        existing: {
          'reference': {
            'goal_code': 'slalom_ball_course_16m',
            'goal_measurement': 'TIME_FOR_COURSE',
            'reference_kind': 'performed_set',
            'targets': [12.5],
            'observed_on': DateTime.now().toIso8601String().split('T').first,
            'frequency': 1,
            'task': {
              'exercise_code': 'slalom_ball_course_16m',
              'measurement': 'TIME_FOR_COURSE',
            },
          },
        },
      );
      await _tap(tester, 'Continuar');
      await _tap(tester, 'Continuar');
      final frequency = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<int> &&
            widget.decoration.labelText == 'Sesiones toleradas',
      );
      await tester.ensureVisible(frequency);
      await tester.tap(frequency);
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 sesiones por semana').last);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin guardar la referencia?'), findsOneWidget);
    },
  );

  testWidgets(
    'la respuesta de guardar no cierra una pantalla que se abre después',
    (tester) async {
      final gate = Completer<void>();
      final capture = await _mount(tester, onSave: (_) => gate.future);
      await _oneSeriesToContext(tester);
      await _tap(tester, 'Guardar referencia');
      unawaited(
        capture.dialogRoute!.navigator!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Otra pantalla')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Otra pantalla'), findsOneWidget);
      expect(capture.result!.reference['targets'], [12.5]);
      expect(capture.dialogRoute!.navigator, isNull);
      expect(capture.saves, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

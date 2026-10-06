import 'dart:convert';
import 'dart:io';

import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/performance_reference_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';

import '../../../helpers/performance_visual_review.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadReviewFont);
  for (final scenario in [
    ('front_plank_forearms', 'DURATION', 'Segundos válidos', '55'),
    ('bench_press_barbell', 'MAX_LOAD', 'Repeticiones con carga', '12'),
    (
      'slalom_ball_course_16m',
      'TIME_FOR_COURSE',
      'Tiempo de circuito',
      '13,25',
    ),
  ]) {
    testWidgets(
      '${scenario.$1}: guarda un intento sin descanso ni detalles inventados',
      (t) async {
        t.view.physicalSize = const Size(390, 850);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final catalog = [
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
        ];
        final data = PreparationTrainingData(
          catalog: catalog,
          context: null,
          runningContext: null,
          references: const [],
          objectives: const [],
          relations: const [],
          publishedWeeks: const [],
        );
        PerformanceReferenceInput? result;
        var saveCalls = 0;
        await t.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('review-boundary'),
            child: MaterialApp(
              theme: EntrenaTheme.dark,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showDialog<PerformanceReferenceInput>(
                        context: context,
                        builder: (_) => PerformanceReferenceDialog(
                          data: data,
                          onSave: (_) async {
                            saveCalls++;
                            if (saveCalls == 1) throw StateError('Sin conexión');
                          },
                          objective: {
                            'name': 'Prueba',
                            'profile_code': scenario.$1,
                            'measurement': scenario.$2,
                            'protocol_key': 'standard_test',
                            'protocol_version': 1,
                            'parameters': const {},
                            'instructions': 'Sigue la técnica indicada.',
                          },
                        ),
                      );
                    },
                    child: const Text('Abrir'),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Abrir'));
        await t.pumpAndSettle();
        await capturePerformanceWidget(t, '${scenario.$1}_tipo');
        await t.tap(
          find.widgetWithText(
            DropdownButtonFormField<String>,
            'Qué estás registrando',
          ),
        );
        await t.pumpAndSettle();
        if (scenario.$2 == 'MAX_LOAD') {
          expect(
            find.text('Una marca con el protocolo de la prueba'),
            findsNothing,
          );
        }
        await t.tap(find.text('Una serie de entrenamiento').last);
        await t.pumpAndSettle();
        await t.tap(find.text('Continuar'));
        await t.pumpAndSettle();
        expect(find.text('Descanso entre series · segundos'), findsNothing);
        final field = find.widgetWithText(
          TextFormField,
          'Serie 1 · ${scenario.$3}',
        );
        await t.ensureVisible(field);
        await t.enterText(field, scenario.$4);
        if (scenario.$2 == 'MAX_LOAD') {
          final loadField = find.widgetWithText(
            TextFormField,
            'Carga externa utilizada · kg',
          );
          await t.ensureVisible(loadField);
          await t.enterText(loadField, '40');
        }
        await t.pumpAndSettle();
        await capturePerformanceWidget(t, '${scenario.$1}_dato');
        await t.tap(find.text('Continuar'));
        await t.pumpAndSettle();
        final checkboxCount = find.byType(CheckboxListTile).evaluate().length;
        await capturePerformanceWidget(t, '${scenario.$1}_contexto');
        for (var i = 0; i < checkboxCount; i++) {
          final finder = find.byType(CheckboxListTile).at(i);
          await t.ensureVisible(finder);
          await t.tap(finder);
          await t.pumpAndSettle();
        }
        await t.tap(find.text('Guardar referencia'));
        await t.pumpAndSettle();
        expect(result, isNull);
        expect(find.textContaining('Tus datos siguen aquí'), findsOneWidget);
        await t.tap(find.text('Atrás'));
        await t.pumpAndSettle();
        expect(t.widget<TextFormField>(field).controller!.text, scenario.$4);
        await t.tap(find.text('Continuar'));
        await t.pumpAndSettle();
        await t.tap(find.text('Guardar referencia'));
        await t.pumpAndSettle();
        expect(saveCalls, 2);
        expect(result, isNotNull);
        expect(result!.reference['targets'], [
          double.parse(scenario.$4.replaceAll(',', '.')),
        ]);
        expect(result!.reference['rest_seconds'], 0);
        expect(
          (result!.reference['task'] as Map)['setup_key'],
          startsWith('standard:'),
        );
        expect(result!.reference['reported_rir'], isNull);
        expect(result!.reference['reference_kind'], 'performed_set');
        if (scenario.$2 == 'MAX_LOAD') {
          expect(result!.reference.containsKey('rep_min'), isFalse);
          expect(result!.reference.containsKey('rep_max'), isFalse);
          expect((result!.reference['task'] as Map)['external_load_kg'], 40);
        }
        expect(t.takeException(), isNull);
      },
    );
  }
}

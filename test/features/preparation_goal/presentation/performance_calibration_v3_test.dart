import 'dart:convert';
import 'dart:io';

import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/performance_reference_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';

void main() {
  for (final scenario in [
    ('bench_press_barbell', null, 'LOAD_REPS'),
    ('push_up_standard', 'REPS_IN_TIME', 'REPS_IN_TIME'),
  ]) {
    testWidgets(
      'calibrar ${scenario.$1} preselecciona medición, sin inventar capacidad',
      (tester) async {
        final catalog = StrengthExerciseCatalogCodec.decode(
          jsonDecode(
            File('supabase/catalogs/strength_exercises_v1.json')
                .readAsStringSync(),
          ),
        ).exercises;
        final data = PreparationTrainingData(
          catalog: catalog,
          context: null,
          runningContext: null,
          references: const [],
          objectives: const [],
          publishedWeeks: const [],
          relations: const [
            {
              'goal_code': 'push_up_standard',
              'work_code': 'bench_press_barbell',
              'role': 'support',
            },
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PerformanceReferenceDialog(
                data: data,
                initialWorkCode: scenario.$1,
                initialMeasurement: scenario.$2,
                objective: const {
                  'profile_code': 'push_up_standard',
                  'measurement': 'REPS_IN_TIME',
                  'name': 'Flexiones en dos minutos',
                  'protocol_key': 'two_minutes',
                  'protocol_version': 1,
                  'parameters': {'fixed_duration_seconds': 120},
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final variant = tester.widget<DropdownButtonFormField<String>>(
          find.byKey(ValueKey('variant_push_up_standard_${scenario.$1}')),
        );
        expect(variant.initialValue, scenario.$1);
        // El formulario pide una práctica nueva: no recibe una referencia ficticia
        // de banca calculada desde el dato de flexiones.
        expect(find.text('55'), findsNothing);
        expect(find.text('Qué estás registrando'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

import 'package:entrenaop/features/workouts/presentation/widgets/performance_result_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/performance_set.dart';

void main() {
  for (final mode in [
    'REPS_IN_TIME',
    'TIME_FOR_DISTANCE',
    'DURATION',
    'HEIGHT',
    'MAX_LOAD',
  ]) {
    testWidgets(
      'control $mode informa protocolo, sin exigir la marca anterior',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PerformanceResultForm(
                  prescription: PerformanceSetPrescription(
                    exerciseCode: 'fixture',
                    exerciseVersion: 1,
                    protocolKey: 'fixture',
                    protocolVersion: 1,
                    setupKey: 'standard:fixture',
                    measurement: mode,
                    loadMode: 'bodyweight',
                    policyVersion: 'adaptive_protocol_control_v1',
                    targetValue: mode == 'DURATION' ? 240 : 1,
                    intent: 'control',
                    fixedDurationSeconds: mode == 'REPS_IN_TIME' ? 120 : null,
                    fixedDistanceMeters: mode == 'TIME_FOR_DISTANCE'
                        ? 2000
                        : null,
                    effortMode: 'rpe',
                    targetRpe: 10,
                  ),
                  onSave: (_, _) {},
                ),
              ),
            ),
          ),
        );
        expect(find.textContaining('Objetivo:'), findsNothing);
        expect(
          find.textContaining('Repeticiones que te quedaban'),
          findsNothing,
        );
        expect(find.textContaining('No necesitas llegar a 10'), findsOneWidget);
        expect(find.textContaining('Hoy no superes'), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
}

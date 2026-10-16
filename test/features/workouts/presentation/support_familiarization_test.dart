import 'package:entrenaop/features/workouts/presentation/widgets/performance_result_form.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/performance_set.dart';

import '../../../helpers/performance_visual_review.dart';

void main() {
  setUpAll(loadReviewFont);
  for (final loadMode in ['external_load', 'bodyweight_plus_external']) {
    testWidgets('primera práctica explica y registra carga real: $loadMode', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      PerformanceSetResult? saved;
      final p = PerformanceSetPrescription(
        exerciseCode: loadMode == 'external_load'
            ? 'bench_press_barbell'
            : 'push_up_weighted',
        exerciseVersion: 1,
        protocolKey: 'support_work_v1',
        protocolVersion: 1,
        setupKey: 'standard:support_v1',
        measurement: 'LOAD_REPS',
        loadMode: loadMode,
        policyVersion: 'support_familiarization_v1',
        targetValue: 8,
        effortMode: 'rir',
        targetRir: 3,
        instructions:
            'Prepara un banco estable y los seguros o ayuda necesarios. '
            'Si no conoces el ejercicio o no puedes prepararlo con seguridad, '
            'omite este apoyo. Haz hasta ocho repeticiones y termina antes '
            'si crees que solo podrías hacer tres más con buena técnica. '
            'Registra lo que has realizado.',
      );
      await t.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('review-boundary'),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: PerformanceResultForm(
                  prescription: p,
                  onSave: (r, _) => saved = r,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await capturePerformanceWidget(t, 'support-first-practice-$loadMode');
      expect(find.text('Conoce este apoyo'), findsOneWidget);
      expect(find.textContaining('no hay kilos obligatorios'), findsOneWidget);
      expect(
        find.textContaining('Puedes omitir este ejercicio'),
        findsOneWidget,
      );
      // No se transforma una pauta de ocho en un resultado ni se inventan kilos.
      for (final field in t.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.controller?.text ?? '', isEmpty);
      }
      Finder field(String label) => find.widgetWithText(TextFormField, label);
      await t.enterText(field('Resultado · repeticiones válidas'), '8');
      await t.enterText(field('Carga externa real · kg'), '12');
      if (loadMode == 'bodyweight_plus_external') {
        await t.enterText(field('Masa corporal actual · kg'), '75');
      }
      final rir = find.text('Repeticiones que te quedaban · 0 a 10');
      await t.ensureVisible(rir);
      await t.tap(rir);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ChoiceChip, '3'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Guardar resultado'));
      await t.tap(find.text('Guardar resultado'));
      await t.pumpAndSettle();
      expect(saved?.value, 8);
      expect(saved?.loadKg, 12);
      expect(saved?.rir, 3);
      expect(saved?.bodyMassKg, loadMode == 'external_load' ? null : 75);
      expect(saved?.techniqueValid, isNull);
      expect(t.takeException(), isNull);
    });
  }
}

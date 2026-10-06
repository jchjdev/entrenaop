import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_path.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/program_phase_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/performance_visual_review.dart';

void main() {
  setUpAll(loadReviewFont);
  testWidgets('fase real y fechas previstas se distinguen en móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final path = AdaptiveProgramPath.fromJson({
      'note': 'Fechas orientativas. Cada objetivo conserva su fase real.',
      'stages': [
        {
          'code': 'base',
          'name': 'Consolidar el punto de partida',
          'starts_on': '2026-10-05',
          'ends_on': '2026-10-18',
          'purpose': 'Confirmar técnica y una dosis practicable.',
        },
        {
          'code': 'development',
          'name': 'Desarrollar fuerza y resistencia',
          'starts_on': '2026-10-19',
          'ends_on': '2026-12-16',
          'purpose': 'Trabajo específico y apoyos con datos propios.',
        },
        {
          'code': 'specific',
          'name': 'Preparar el formato del examen',
          'starts_on': '2026-12-17',
          'ends_on': '2027-01-06',
          'purpose': 'Priorizar las condiciones de la prueba.',
        },
        {
          'code': 'taper',
          'name': 'Llegar recuperado',
          'starts_on': '2027-01-07',
          'ends_on': '2027-01-13',
          'purpose': 'Menos trabajo fatigante, sin máximos.',
        },
      ],
      'objectives': [
        {
          'code': 'base',
          'name': 'Consolidar el punto de partida',
          'exercise_name': 'Flexiones',
          'purpose': 'Consolidar técnica antes de ampliar la exigencia.',
        },
        {
          'code': 'development',
          'name': 'Desarrollar fuerza y resistencia',
          'exercise_name': 'Plancha',
          'purpose': 'Desarrollar trabajo de postura con calidad.',
        },
      ],
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('review-boundary'),
        child: MaterialApp(
          theme: EntrenaTheme.dark,
          home: Scaffold(
            appBar: AppBar(title: const Text('Mi programa')),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [ProgramPhaseSection(path: path)],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Flexiones'), findsOneWidget);
    expect(find.textContaining('orientativo'), findsNothing);
    await tester.pumpAndSettle();
    await capturePerformanceWidget(tester, 'programa_v3_semana');
    await tester.tap(find.text('Mis fases'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fechas orientativas'), findsOneWidget);
    expect(find.textContaining('05/10 – 18/10'), findsOneWidget);
    expect(find.text('Flexiones'), findsNothing);
    await tester.tap(find.text('Consolidar el punto de partida'));
    await tester.pumpAndSettle();
    expect(find.text('Ahora: Flexiones'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capturePerformanceWidget(tester, 'programa_v3_fases');
  });
}

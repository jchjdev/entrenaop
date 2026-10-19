import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_pages.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/guided_program.dart';

import '../../../../test/helpers/performance_visual_review.dart';

const _category = GuidedProgramCategory(
  id: 'strength',
  name: 'Fuerza e iniciación',
);

class _Guided extends Fake implements AdminGuidedRepository {
  @override
  Future<List<GuidedProgramCategory>> categories() async => [_category];
  @override
  Future<List<GuidedWarmup>> warmups() async => const [
    GuidedWarmup(
      id: 'warmup',
      templateId: 'activation',
      name: 'Activación de tirón y movilidad de hombros',
      version: 1,
      status: 'published',
    ),
  ];
}

class _Workouts extends Fake implements AdminWorkoutRepository {
  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async => const [
    AdminWorkoutSummary(
      id: 'session',
      name: 'Empuje de cadera y trabajo complementario',
      status: 'published',
      version: 1,
      isRunning: false,
      catalogScope: 'general',
    ),
    AdminWorkoutSummary(
      id: 'own-warmup',
      name: 'Sesión con calentamiento propio',
      status: 'published',
      version: 1,
      isRunning: false,
      catalogScope: 'general',
      hasWarmup: true,
      supportsAdjustableRest: false,
    ),
  ];
}

Future<void> _show(WidgetTester tester, Finder target) async {
  final scroll = find.byType(Scrollable).first;
  tester.state<ScrollableState>(scroll).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 250, scrollable: scroll);
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.45);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _separateLabel(
  WidgetTester tester,
  String label,
  Finder previous,
) async {
  final field = find.byKey(ValueKey('program-label-$label'));
  await _show(tester, field);
  final labelRect = tester.getRect(
    find.descendant(of: field, matching: find.text(label)).first,
  );
  expect(
    labelRect.top - tester.getRect(previous).bottom,
    greaterThanOrEqualTo(4),
    reason: 'La etiqueta «$label» debe separarse del control anterior.',
  );
}

void main() {
  setUpAll(() => loadReviewFont(always: true));
  for (final width in [320.0, 390.0, 1100.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final mode in GuidedProgramMode.values) {
        testWidgets('creador ${mode.name} a $width px y texto $scale×', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(Size(width, 950));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final name = 'program-creator-${mode.name}-${width.toInt()}-$scale';
          await tester.pumpWidget(
            MaterialApp(
              theme: EntrenaTheme.dark,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                  key: const ValueKey('review-boundary'),
                  child: child!,
                ),
              ),
              home: AdminGuidedEditorPage(
                repository: _Guided(),
                workouts: _Workouts(),
                original: GuidedProgram(
                  id: 'program',
                  name: 'Programa de fuerza e iniciación',
                  mode: mode,
                  categories: const [_category],
                  primaryCategoryId: _category.id,
                  phases: const [
                    GuidedPhase(
                      name: 'Preparación inicial',
                      durationWeeks: 3,
                      instructions: 'Completar las sesiones con control.',
                      sessions: [
                        GuidedSession(
                          templateId: 'session',
                          name: 'Empuje de cadera y trabajo complementario',
                          warmupId: 'warmup',
                          restPolicy: GuidedRestPolicy(
                            minimumSeconds: 60,
                            maximumSeconds: 180,
                          ),
                        ),
                        GuidedSession(
                          templateId: 'own-warmup',
                          name: 'Sesión con calentamiento propio',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await capturePerformanceWidget(tester, '$name-top');
          await _separateLabel(
            tester,
            'Categoría principal',
            find.widgetWithText(FilterChip, _category.name),
          );
          final categoryText = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.widgetWithText(FilterChip, _category.name),
              matching: find.byType(RichText),
            ),
          );
          final lastLetter = categoryText.getBoxesForSelection(
            TextSelection(
              baseOffset: _category.name.length - 1,
              extentOffset: _category.name.length,
            ),
          );
          expect(lastLetter, isNotEmpty);
          expect(
            lastLetter.last.bottom,
            lessThanOrEqualTo(categoryText.size.height + 1),
          );
          await capturePerformanceWidget(tester, '$name-categories');
          if (mode == GuidedProgramMode.phased) {
            await _separateLabel(
              tester,
              'Nombre de la fase',
              find.text('Fase 1'),
            );
            await capturePerformanceWidget(tester, '$name-phase');
          }
          await _separateLabel(
            tester,
            'Calentamiento adjunto',
            find.widgetWithText(TextButton, 'Revisar sesión').first,
          );
          await capturePerformanceWidget(tester, '$name-session');
          await _separateLabel(
            tester,
            'Descanso mínimo (segundos)',
            find
                .byKey(
                  const ValueKey(
                    'program-switch-Permitir ajustar descansos entre series',
                  ),
                )
                .first,
          );
          final minimum = find
              .byKey(const ValueKey('program-field-Descanso mínimo (segundos)'))
              .first;
          await _separateLabel(tester, 'Descanso máximo (segundos)', minimum);
          await capturePerformanceWidget(tester, '$name-rest');
          await _show(tester, find.text('Guardar y revisar'));
          await capturePerformanceWidget(tester, '$name-actions');
          expect(
            find.text('Esta sesión ya incluye su propio calentamiento.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

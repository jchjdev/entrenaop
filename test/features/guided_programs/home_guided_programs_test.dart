import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';
import 'package:entrenaop/features/guided_programs/presentation/home_guided_programs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/guided_program.dart';

import '../../helpers/performance_visual_review.dart';
import '../../support/guided_program_fixture.dart';

const phased = GuidedProgram(
  id: 'phased',
  name: 'Mejora de dominadas',
  mode: GuidedProgramMode.phased,
  phases: [
    GuidedPhase(name: 'Base', sessions: []),
    GuidedPhase(name: 'Progreso', sessions: []),
    GuidedPhase(name: 'Consolidación', sessions: []),
  ],
);

void main() {
  // La regresión compara alturas de texto: usa las métricas reales de Roboto.
  setUpAll(() => loadReviewFont(always: true));
  Future<void> mount(
    WidgetTester tester,
    double width,
    double scale,
    _Programs repo,
    Future<void> Function(String) onOpen,
  ) async {
    await tester.binding.setSurfaceSize(Size(width, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: HomeGuidedPrograms(
              repository: repo,
              refreshVersion: 0,
              onOpen: onOpen,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final view in [(390.0, 1.0), (320.0, 2.0), (1100.0, 1.0)]) {
    testWidgets(
      'tarjetas compactas alineadas y desplazamiento horizontal a $view',
      (tester) async {
        final routes = <String>[];
        await mount(tester, view.$1, view.$2, _Programs(), (route) async {
          routes.add(route);
        });
        final first = find.byKey(const ValueKey('home-guided-card-program'));
        final second = find.byKey(const ValueKey('home-guided-card-phased'));
        expect(tester.getSize(first).width, 250);
        expect(tester.getSize(second).width, 250);
        for (final (card, name, detail) in [
          (first, 'Hipertrofia básica', '1 sesión'),
          (second, 'Mejora de dominadas', 'Fase 1 de 3'),
        ]) {
          final title = find.descendant(of: card, matching: find.text(name));
          final subtitle = find.descendant(
            of: card,
            matching: find.text(detail),
          );
          expect(
            tester.getTopLeft(subtitle).dy - tester.getBottomLeft(title).dy,
            closeTo(6, 0.01),
          );
          expect(
            tester.getBottomLeft(card).dy -
                tester
                    .getBottomLeft(
                      find.descendant(
                        of: card,
                        matching: find.text('Ver programa →'),
                      ),
                    )
                    .dy,
            // El borde de la superficie añade un píxel al relleno inferior.
            closeTo(19, 0.01),
          );
        }
        final title = tester.renderObject<RenderBox>(
          find.text('Hipertrofia básica'),
        );
        expect(
          title.size.height,
          greaterThanOrEqualTo(
            title.getMinIntrinsicHeight(title.size.width) - 0.1,
          ),
        );
        expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
        expect(
          tester.getTopLeft(second).dx,
          greaterThan(tester.getTopRight(first).dx),
        );
        if (capturePerformanceReview) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pumpAndSettle();
        }
        await capturePerformanceWidget(
          tester,
          'programas-inicio-carrusel-${view.$1}-${view.$2}',
        );
        final carousel = find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        );
        if (view.$1 < 500) {
          final before = tester.getTopLeft(first).dx;
          await tester.drag(carousel, const Offset(-220, 0));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(first).dx, lessThan(before));
        }
        await tester.tap(second);
        await tester.pumpAndSettle();
        expect(routes.single, '/library/programs/phased');
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final view in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'añadir programa reserva el espacio de un título de dos líneas a $view',
      (tester) async {
        final routes = <String>[];
        await mount(tester, view.$1, view.$2, _Programs()..empty = true, (
          route,
        ) async {
          routes.add(route);
        });
        final card = find.byKey(const ValueKey('home-guided-card-add'));
        expect(tester.getSize(card).width, 250);
        final emptyHeight = tester.getSize(card).height;
        final emptyTitleToDetail =
            tester.getTopLeft(find.text('Elige un programa')).dy -
            tester.getTopLeft(find.text('Añadir programa')).dy;
        expect(find.text('Añadir programa'), findsOneWidget);
        final title = tester.renderObject<RenderBox>(
          find.text('Añadir programa'),
        );
        expect(
          title.size.height,
          greaterThanOrEqualTo(
            title.getMinIntrinsicHeight(title.size.width) - 0.1,
          ),
        );
        await tester.tap(card);
        expect(routes.single, '/library?tab=programs');
        expect(tester.takeException(), isNull);
        await capturePerformanceWidget(
          tester,
          'programas-inicio-vacio-${view.$1}-${view.$2}',
        );
        await mount(
          tester,
          view.$1,
          view.$2,
          _Programs(
            first: const GuidedProgram(
              id: 'program',
              name: 'Glúteos · Empuje de cadera y sentadilla',
              mode: GuidedProgramMode.guide,
              phases: [GuidedPhase(name: 'Rutina', sessions: [])],
            ),
          ),
          (_) async {},
        );
        final started = find.byKey(const ValueKey('home-guided-card-program'));
        expect(
          tester.getTopLeft(find.text('0 sesiones')).dy -
              tester
                  .getTopLeft(
                    find.text('Glúteos · Empuje de cadera y sentadilla'),
                  )
                  .dy,
          closeTo(emptyTitleToDetail, 0.1),
        );
        if (view.$2 == 1) {
          expect(tester.getSize(started).height, closeTo(emptyHeight, 0.1));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Programs extends GuidedTestRepository {
  _Programs({this.first = guidedFixture});
  final GuidedProgram first;
  bool empty = false;
  @override
  Future<List<StartedGuidedProgram>> startedPrograms() async => empty
      ? []
      : [
          StartedGuidedProgram(program: first, phaseIndex: 0),
          const StartedGuidedProgram(program: phased, phaseIndex: 0),
        ];
}

import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/library/presentation/library_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/performance_visual_review.dart';
import '../../support/guided_program_fixture.dart';

void main() {
  setUpAll(() => loadReviewFont(always: true));

  for (final showPrograms in [true, false]) {
    for (final (width, scale) in [
      (320.0, 1.0),
      (390.0, 1.0),
      (390.0, 1.2),
      (390.0, 1.4),
      (320.0, 2.0),
      (1100.0, 1.0),
    ]) {
      testWidgets(
        'pestañas completas con programas=$showPrograms en $width px y texto x$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
          addTearDown(tester.view.reset);
          final router = _router(showPrograms);
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: EntrenaTheme.dark,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final labels = [
            if (showPrograms) 'Programas',
            'Sesiones',
            'Ejercicios',
          ];
          for (final selected in labels) {
            await tester.ensureVisible(find.text(selected));
            await tester.pumpAndSettle();
            await tester.tap(find.text(selected));
            await tester.pumpAndSettle();
            for (final label in labels) {
              final paragraph = tester.renderObject<RenderParagraph>(
                find.text(label),
              );
              expect(
                paragraph.size.width + .5,
                greaterThanOrEqualTo(
                  paragraph.getMaxIntrinsicWidth(double.infinity),
                ),
                reason: '$label debe leerse completo al seleccionar $selected.',
              );
            }
            final visible = tester.getRect(find.text(selected));
            final bar = tester.getRect(find.byType(TabBar));
            expect(visible.left, greaterThanOrEqualTo(bar.left - .5));
            expect(visible.right, lessThanOrEqualTo(bar.right + .5));
            expect(
              find.text(switch (selected) {
                'Programas' => 'Hipertrofia básica',
                'Sesiones' => 'Sesiones EntrenaOP',
                _ => 'Ejercicios EntrenaOP',
              }).hitTestable(),
              findsOneWidget,
            );
            if (selected == 'Programas') {
              if (width == 390 && scale == 1.2) {
                expect(
                  tester.widget<TabBar>(find.byType(TabBar)).isScrollable,
                  isFalse,
                );
              }
              await capturePerformanceWidget(
                tester,
                'biblioteca-pestanas-${width.toInt()}-$scale',
              );
            }
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}

GoRouter _router(bool showPrograms) {
  final repository = GuidedTestRepository()..morePages = false;
  return GoRouter(
    initialLocation: '/library',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: AppShell(navigationShell: shell),
        ),
        branches: [
          for (final path in [
            '/home',
            '/plan',
            '/library',
            '/evolution',
            '/profile',
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (_, _) => path == '/library'
                      ? LibraryHubPage(
                          guided: showPrograms ? repository : null,
                          initialTab: showPrograms ? 'programs' : 'sessions',
                        )
                      : const Scaffold(),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

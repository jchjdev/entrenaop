import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<GoRouter> mount(
    WidgetTester tester,
    Size size, {
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (_, state, child) =>
              TrainerShell(location: state.uri.path, child: child),
          routes: [
            for (final path in ['/home', '/workouts/new'])
              GoRoute(
                path: path,
                builder: (_, _) => const Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 240,
                      child: TextField(key: ValueKey('draft')),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'la calculadora sigue abierta al entrar al creador y no altera el borrador',
    (tester) async {
      final router = await mount(tester, const Size(1440, 900));
      await tester.ensureVisible(find.text('Herramientas'));
      await tester.tap(find.text('Herramientas'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PopupMenuItem<void>, 'Calculadora de ritmos'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('running-pace-input')),
        '415',
      );
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('running-compact-result')))
            .data,
        '1:42',
      );
      expect(
        find.byKey(const ValueKey('running-compact-result')).hitTestable(),
        findsOneWidget,
      );
      router.go('/workouts/new');
      await tester.pumpAndSettle();
      expect(find.text('04:15'), findsWidgets);
      await tester.enterText(find.byKey(const ValueKey('draft')), 'Fuerza A');
      await tester.tap(find.byTooltip('Minimizar calculadora'));
      await tester.pump();
      await tester.tap(find.text('Herramientas'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PopupMenuItem<void>, 'Calculadora de ritmos'),
      );
      await tester.pumpAndSettle();
      expect(find.text('04:15'), findsWidgets);
      expect(find.text('Fuerza A'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/workouts/new');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Más abre ritmos en pantalla estrecha con texto ampliado', (
    tester,
  ) async {
    await mount(tester, const Size(320, 700), scale: 2);
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calculadora de ritmos'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('running-pace-input')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Minimizar calculadora'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

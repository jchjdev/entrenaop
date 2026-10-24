import 'package:entrenaop_admin/core/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('ADMIN conserva la calculadora al navegar y deja editar debajo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/sessions',
      routes: [
        ShellRoute(
          builder: (_, state, child) => AdminShell(
            path: state.uri.path,
            hasAccess: () async => true,
            onSignOut: () {},
            child: child,
          ),
          routes: [
            for (final path in ['/sessions', '/sessions/new'])
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
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Herramientas'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PopupMenuItem<void>, 'Calculadora de ritmos'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('running-pace-input')),
      '405',
    );
    await tester.pump();
    router.go('/sessions/new');
    await tester.pumpAndSettle();
    expect(find.text('04:05'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('draft')), 'Series');
    await tester.tap(find.byTooltip('Minimizar calculadora'));
    await tester.pump();
    expect(find.text('Series'), findsOneWidget);
    await tester.tap(find.byTooltip('Restaurar calculadora'));
    await tester.pump();
    expect(find.text('04:05'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Cerrar calculadora'));
    await tester.pump();
    final sidebarTool = find.byKey(const ValueKey('admin-tool-calculator'));
    await tester.scrollUntilVisible(
      sidebarTool,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(sidebarTool);
    await tester.pumpAndSettle();
    expect(find.text('03:40'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('draft')),
        matching: find.text('Series'),
      ),
      findsOneWidget,
    );
    expect(router.routeInformationProvider.value.uri.path, '/sessions/new');
  });
}

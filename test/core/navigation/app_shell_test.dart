import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('usa la barra inferior y cambia de sección en móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await tester.tap(find.text('Mi plan'));
    await tester.pumpAndSettle();

    expect(find.text('Contenido de Mi plan'), findsOneWidget);
    expect(router.state.matchedLocation, '/plan');
  });

  testWidgets('usa navegación lateral en pantallas amplias', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}

GoRouter _createRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          _branch('/home', 'Inicio'),
          _branch('/plan', 'Mi plan'),
          _branch('/assessment/history', 'Evolución'),
          _branch('/profile', 'Perfil'),
        ],
      ),
    ],
  );
}

StatefulShellBranch _branch(String path, String name) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) =>
            Scaffold(body: Center(child: Text('Contenido de $name'))),
      ),
    ],
  );
}

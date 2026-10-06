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
    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/library');
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(5));
    expect(bar.selectedIndex, 2);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/profile');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );
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
  for (final width in [390.0, 1000.0]) {
    testWidgets('conserva sección y segundo toque vuelve a raíz: $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = _createRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/profile/detail');
      await tester.pumpAndSettle();
      expect(find.text('Detalle de Perfil'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.event_note_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/profile/detail');
      expect(find.text('Detalle de Perfil'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.person_rounded));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/profile');
      expect(find.text('Contenido de Perfil'), findsOneWidget);
      expect(find.text('Detalle de Perfil'), findsNothing);
    });
  }
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
          _branch('/library', 'Biblioteca'),
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
        routes: [
          GoRoute(
            path: 'detail',
            builder: (context, state) =>
                Scaffold(body: Text('Detalle de $name')),
          ),
        ],
      ),
    ],
  );
}

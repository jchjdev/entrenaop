import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final saveDraft in [false, true]) {
    testWidgets('tarea sin barra: salida con cambios y borrador $saveDraft', (
      tester,
    ) async {
      final registry = WorkflowExitRegistry();
      final rootKey = GlobalKey<NavigatorState>();
      var dirty = false;
      var drafts = 0;
      final router = GoRouter(
        initialLocation: '/plan',
        navigatorKey: rootKey,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                AppShell(navigationShell: shell),
            branches: [
              for (final route in [
                '/home',
                '/plan',
                '/library',
                '/history',
                '/profile',
              ])
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: route,
                      builder: (context, state) => Scaffold(body: Text(route)),
                      routes: route == '/plan'
                          ? [
                              GoRoute(
                                path: 'flow',
                                parentNavigatorKey: rootKey,
                                onExit: (context, state) =>
                                    registry.requestExit(state.pageKey),
                                builder: (context, state) => WorkflowExitScope(
                                  controller: registry.controller(
                                    state.pageKey,
                                  ),
                                  child: WorkflowDraftGuard(
                                    hasUnsavedChanges: () => dirty,
                                    saveDraftBeforeExit: saveDraft
                                        ? () async {
                                            drafts++;
                                            dirty = false;
                                            return true;
                                          }
                                        : null,
                                    child: Scaffold(
                                      appBar: AppBar(
                                        leading: IconButton(
                                          icon: const Icon(Icons.arrow_back),
                                          onPressed: context.pop,
                                        ),
                                      ),
                                      body: TextField(
                                        onChanged: (_) => dirty = true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ]
                          : [],
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      router.push('/plan/flow');
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      await tester.enterText(find.byType(TextField), 'dato sin guardar');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      if (!saveDraft) {
        expect(find.text('¿Salir sin guardar?'), findsOneWidget);
        await tester.tap(find.text('Seguir aquí'));
        await tester.pumpAndSettle();
        expect(find.text('dato sin guardar'), findsOneWidget);
        // Una navegación directa (incluido el historial web) pasa por el mismo guard.
        router.go('/profile');
        await tester.pumpAndSettle();
        expect(find.text('¿Salir sin guardar?'), findsOneWidget);
        await tester.tap(find.text('Salir sin guardar'));
        await tester.pumpAndSettle();
        expect(router.state.matchedLocation, '/profile');
      } else {
        expect(drafts, 1);
        expect(find.byType(AlertDialog), findsNothing);
        expect(router.state.matchedLocation, '/plan');
      }
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

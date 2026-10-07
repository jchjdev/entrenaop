import 'package:entrenaop/core/navigation/section_refresh_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('volver de otra rama actualiza sin perder texto ni scroll', (
    tester,
  ) async {
    var refreshes = 0;
    final router = _router(() async => refreshes++);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(refreshes, 0);
    await tester.enterText(find.byType(TextField), 'Selección conservada');
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final position = scroll.position.pixels;
    router.go('/other');
    await tester.pumpAndSettle();
    expect(refreshes, 0);
    router.go('/home');
    await tester.pumpAndSettle();
    expect(refreshes, 1);
    expect(scroll.position.pixels, position);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Selección conservada',
    );
  });

  testWidgets('volver de una tarea raíz refresca; un cambio de query no', (
    tester,
  ) async {
    var refreshes = 0;
    final router = _router(() async => refreshes++);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final task = router.push('/task');
    await tester.pumpAndSettle();
    expect(refreshes, 0);
    router.pop();
    await tester.pumpAndSettle();
    await task;
    expect(refreshes, 1);
    router.go('/home?day=2026-10-07');
    await tester.pumpAndSettle();
    expect(refreshes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    router.go('/other');
    await tester.pumpAndSettle();
    expect(refreshes, 1);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _router(Future<void> Function() refresh) => GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => shell,
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => SectionRefreshBoundary(
                location: '/home',
                onVisible: refresh,
                child: const _Consultation(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/other',
              builder: (_, _) => const Scaffold(body: Text('Otra sección')),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/task',
      builder: (_, _) => const Scaffold(body: Text('Tarea')),
    ),
  ],
);

class _Consultation extends StatefulWidget {
  const _Consultation();
  @override
  State<_Consultation> createState() => _ConsultationState();
}

class _ConsultationState extends State<_Consultation> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: [
        TextField(controller: _controller),
        for (var i = 0; i < 40; i++) ListTile(title: Text('Sesión $i')),
      ],
    ),
  );
}

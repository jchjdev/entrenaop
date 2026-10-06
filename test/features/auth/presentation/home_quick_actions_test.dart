import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_tools_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final width in [320.0, 1100.0]) {
    testWidgets(
      'las dos herramientas están visibles a $width px sin preparación',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(20),
                  child: HomeToolsSection(),
                ),
              ),
            ),
            GoRoute(
              path: '/tools/running-pace-calculator',
              builder: (_, _) => const Scaffold(body: Text('Destino ritmos')),
            ),
            GoRoute(
              path: '/assessment/fas-calculator',
              builder: (_, _) =>
                  const Scaffold(body: Text('Destino calculadora')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
        );
        expect(find.text('Ritmos de carrera'), findsOneWidget);
        expect(find.text('PAEF / PAFAS'), findsOneWidget);
        expect(find.text('Consulta de puntos · gratis'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Ritmos de carrera'));
        await tester.pumpAndSettle();
        expect(find.text('Destino ritmos'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('PAEF / PAFAS'));
        await tester.pumpAndSettle();
        expect(find.text('Destino calculadora'), findsOneWidget);
      },
    );
  }
}

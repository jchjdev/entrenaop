import 'package:entrenaop/features/auth/presentation/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('la calculadora FAS está visible sin preparación ni Premium', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: HomeQuickActions(
              assessment: null,
              hasTroop: false,
              fasGoal: null,
            ),
          ),
        ),
        GoRoute(
          path: '/assessment/fas-calculator',
          builder: (context, state) => const Scaffold(
            body: Text('Destino calculadora'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Calculadora FAS'), findsOneWidget);
    expect(find.text('Puntos PAFAS/PAEF 2027 · gratis'), findsOneWidget);

    await tester.tap(find.text('Calculadora FAS'));
    await tester.pumpAndSettle();
    expect(find.text('Destino calculadora'), findsOneWidget);
  });
}

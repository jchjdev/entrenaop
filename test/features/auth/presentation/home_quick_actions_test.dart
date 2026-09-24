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
          builder: (context, state) =>
              const Scaffold(body: Text('Destino calculadora')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Calculadora FAS'), findsOneWidget);
    expect(find.text('Puntos PAFAS/PAEF 2027 · gratis'), findsOneWidget);

    final calculator = find.text('Calculadora FAS');
    await tester.ensureVisible(calculator);
    await tester.pumpAndSettle();
    await tester.tap(calculator);
    await tester.pumpAndSettle();
    expect(find.text('Destino calculadora'), findsOneWidget);
  });

  testWidgets('ofrece acceso directo al creador de ejercicios personales', (
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
          path: '/exercises/new',
          builder: (context, state) =>
              const Scaffold(body: Text('Destino creador personal')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('Crear ejercicio'), findsOneWidget);
    expect(find.text('Añadir un ejercicio personal'), findsOneWidget);

    await tester.tap(find.text('Crear ejercicio'));
    await tester.pumpAndSettle();
    expect(find.text('Destino creador personal'), findsOneWidget);
  });
}

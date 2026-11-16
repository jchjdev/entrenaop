import 'package:entrenaop_trainer/trainer_account_page.dart';
import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import 'trainer_security_page_test.dart' show SecurityFake;

class UnavailableAccess extends FakeTrainerRepository {
  @override
  Future<TrainerAccess> access() async =>
      throw StateError('No se pudo consultar el acceso');
}

void main() {
  testWidgets('Trainer abre la guía desde Más y Mi cuenta', (tester) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final guide = ProfessionalGuideController(
      panel: 'trainer',
      accountId: 'guide-test',
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (_, state, child) => TrainerShell(
            location: state.uri.path,
            guide: guide,
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Text('Inicio de prueba'),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, _) => TrainerAccountPage(
                email: 'ana@example.invalid',
                access: UnavailableAccess(),
                security: SecurityFake(),
                onSignOut: () async {},
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guía de uso'));
    await tester.pumpAndSettle();
    expect(find.text('Invita a tu primer alumno'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    router.go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guía de uso'));
    await tester.pumpAndSettle();
    expect(find.text('Invita a tu primer alumno'), findsOneWidget);
  });

  testWidgets(
    'facturación sigue accesible aunque falle la consulta del acceso',
    (t) async {
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => TrainerAccountPage(
              email: 'ana@example.invalid',
              access: UnavailableAccess(),
              security: SecurityFake(),
              onSignOut: () async {},
            ),
          ),
          GoRoute(
            path: '/subscription',
            builder: (_, _) => const Scaffold(body: Text('Planes de ensayo')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      final billing = find.widgetWithText(
        FilledButton,
        'Gestionar plan y facturación',
      );
      expect(billing, findsOneWidget);
      await t.tap(billing);
      await t.pumpAndSettle();
      expect(find.text('Planes de ensayo'), findsOneWidget);
    },
  );
}

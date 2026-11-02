import 'package:entrenaop_trainer/trainer_account_page.dart';
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

import 'dart:async';

import 'package:entrenaop_trainer/trainer_self_page.dart';
import 'package:entrenaop_trainer/trainer_client_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'solo abre la ficha propia tras confirmar el alta, con reintento',
    (t) async {
      var attempts = 0;
      final pending = Completer<void>();
      final router = GoRouter(
        initialLocation: '/self',
        routes: [
          GoRoute(
            path: '/self',
            builder: (_, _) => TrainerSelfPage(
              ownerId: 'owner',
              ensure: () async {
                attempts++;
                if (attempts == 1) throw StateError('Error incierto');
                await pending.future;
              },
            ),
          ),
          GoRoute(
            path: '/clients/:id/workouts',
            builder: (_, state) => Text('Ficha ${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Ficha owner'), findsNothing);
      await t.tap(find.text('Reintentar'));
      await t.pump();
      expect(find.text('Ficha owner'), findsNothing);
      pending.complete();
      await t.pumpAndSettle();
      expect(find.text('Ficha owner'), findsOneWidget);
      expect(attempts, 2);
    },
  );

  testWidgets(
    'ficha propia oculta conversación y conserva planificación y resultados',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainerClientNavigation.wrap(
              Uri.parse('/clients/owner/workouts'),
              const Text('Calendario'),
              selfClientId: 'owner',
            ),
          ),
        ),
      );
      expect(find.text('Conversación'), findsNothing);
      expect(find.text('Planificación'), findsOneWidget);
      expect(find.text('Resultados'), findsOneWidget);
    },
  );
}

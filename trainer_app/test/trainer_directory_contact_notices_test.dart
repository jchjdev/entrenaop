import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_messages.dart';

void main() {
  testWidgets(
    'primer contacto llega a la campana sin crear conversación de alumno',
    (t) async {
      final router = GoRouter(
        routes: [
          ShellRoute(
            builder: (_, state, child) => TrainerShell(
              location: state.uri.path,
              loadInbox: () async => const TrainerMessageInbox(
                totalUnread: 0,
                conversations: [],
                contactPending: 1,
                contactUnread: 1,
              ),
              child: child,
            ),
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('Inicio')),
              ),
              GoRoute(
                path: '/contacts',
                builder: (_, _) => const Scaffold(
                  body: Text('Bandeja de contactos de prueba'),
                ),
              ),
            ],
          ),
        ],
      );
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(find.byTooltip('1 mensajes sin leer'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('trainer-message-notices')));
      await t.pumpAndSettle();
      expect(
        find.text('1 solicitudes pendientes · 1 mensajes sin leer'),
        findsOneWidget,
      );
      await t.tap(find.text('Contactos del directorio'));
      await t.pumpAndSettle();
      expect(find.text('Bandeja de contactos de prueba'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      router.dispose();
    },
  );
}

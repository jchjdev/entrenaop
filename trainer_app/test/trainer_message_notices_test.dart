import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_messages.dart';

void main() {
  for (final width in [360.0, 1500.0]) {
    testWidgets(
      'avisa, abre la etapa exacta y oculta la campana al leer a $width',
      (t) async {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var count = 2;
        var calls = 0;
        final changes = ValueNotifier<int>(0);
        final router = GoRouter(
          routes: [
            ShellRoute(
              builder: (_, state, child) => TrainerShell(
                location: state.uri.path,
                messageChanges: changes,
                loadInbox: () async {
                  calls++;
                  return TrainerMessageInbox(
                    totalUnread: count,
                    conversations: count == 0
                        ? []
                        : [
                            TrainerUnreadConversation.fromJson({
                              'relation_id': 'service-a',
                              'client_name': 'Ana Soria',
                              'unread_count': count,
                            }),
                          ],
                  );
                },
                child: child,
              ),
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) =>
                      const Scaffold(body: Text('Inicio de prueba')),
                ),
                GoRoute(
                  path: '/conversations/:id',
                  builder: (_, s) =>
                      Scaffold(body: Text('Etapa ${s.pathParameters['id']}')),
                ),
              ],
            ),
          ],
        );
        await t.pumpWidget(MaterialApp.router(routerConfig: router));
        await t.pumpAndSettle();
        expect(find.byTooltip('2 mensajes sin leer'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('trainer-message-notices')));
        await t.pumpAndSettle();
        expect(find.text('Ana Soria'), findsOneWidget);
        await t.tap(find.text('Ana Soria'));
        await t.pumpAndSettle();
        expect(find.text('Etapa service-a'), findsOneWidget);
        count = 0;
        changes.value++;
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('trainer-message-notices')),
          findsNothing,
        );
        final previous = calls;
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await t.pump(const Duration(seconds: 60));
        expect(calls, previous);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        expect(calls, previous + 1);
        await t.pumpWidget(const SizedBox());
        router.dispose();
        changes.dispose();
      },
    );
  }
}

import 'package:entrenaop_trainer/trainer_clients_page.dart';
import 'package:entrenaop_trainer/trainer_client_directories.dart';
import 'package:entrenaop_trainer/trainer_message_inbox_scope.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_messages.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';

void main() {
  for (final directory in [true, false]) {
    for (final width in [360.0, 1500.0]) {
      testWidgets(
        'globo por alumno en ${directory ? 'Conversaciones' : 'Alumnos'} a $width se actualiza y abre su etapa pendiente',
        (t) async {
          t.view.physicalSize = Size(width, 1200);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final repository = FakeTrainerRepository()
            ..active = [trainerRelation('Ana Soria')];
          final count = ValueNotifier<int>(0);
          final router = GoRouter(
            initialLocation: '/clients',
            routes: [
              GoRoute(
                path: '/clients',
                builder: (_, _) => ValueListenableBuilder<int>(
                  valueListenable: count,
                  builder: (_, value, child) => TrainerMessageInboxScope(
                    inbox: TrainerMessageInbox(
                      totalUnread: value,
                      conversations: const [],
                      clients: value == 0
                          ? const {}
                          : {
                              'person-a': TrainerClientMessageSummary(
                                unreadCount: value,
                                relationId: 'old-unread-episode',
                              ),
                            },
                    ),
                    child: child!,
                  ),
                  child: directory
                      ? TrainerClientDirectoryPage(
                          repository: repository,
                          reports: false,
                        )
                      : TrainerClientsPage(repository: repository),
                ),
              ),
              GoRoute(
                path: '/conversations/:id',
                builder: (_, state) =>
                    Scaffold(body: Text('Etapa ${state.pathParameters['id']}')),
              ),
            ],
          );
          await t.pumpWidget(
            MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
          );
          await t.pumpAndSettle();
          final badge = find.byKey(const ValueKey('client-messages-person-a'));
          expect(badge, findsNothing);
          count.value = 3;
          await t.pumpAndSettle();
          expect(badge, findsOneWidget);
          expect(find.byTooltip('3 mensajes sin leer'), findsOneWidget);
          count.value = 0;
          await t.pumpAndSettle();
          expect(badge, findsNothing);
          count.value = 1;
          await t.pumpAndSettle();
          expect(find.byTooltip('1 mensaje sin leer'), findsOneWidget);
          await t.ensureVisible(badge);
          await t.tap(badge);
          await t.pumpAndSettle();
          expect(find.text('Etapa old-unread-episode'), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          router.dispose();
          count.dispose();
        },
      );
    }
  }
  testWidgets(
    'la tarjeta de conversación abre la etapa con mensajes sin leer',
    (t) async {
      final repository = FakeTrainerRepository()
        ..active = [trainerRelation('Ana Soria')];
      final router = GoRouter(
        initialLocation: '/messages',
        routes: [
          GoRoute(
            path: '/messages',
            builder: (_, _) => TrainerMessageInboxScope(
              inbox: const TrainerMessageInbox(
                totalUnread: 2,
                conversations: [],
                clients: {
                  'person-a': TrainerClientMessageSummary(
                    unreadCount: 2,
                    relationId: 'old-episode',
                  ),
                },
              ),
              child: TrainerClientDirectoryPage(
                repository: repository,
                reports: false,
              ),
            ),
          ),
          GoRoute(
            path: '/conversations/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Etapa ${state.pathParameters['id']}')),
          ),
        ],
      );
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      await t.tap(find.text('Ana Soria'));
      await t.pumpAndSettle();
      expect(find.text('Etapa old-episode'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      router.dispose();
    },
  );
}

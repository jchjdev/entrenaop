import 'package:entrenaop_trainer/trainer_conversations_hub.dart';
import 'package:entrenaop_trainer/trainer_message_inbox_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_messages.dart';

void main() {
  testWidgets('separa contadores y abre contactos desde su aviso a 320 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final unread = ValueNotifier<int>(1);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ValueListenableBuilder<int>(
          valueListenable: unread,
          builder: (_, count, _) => TrainerMessageInboxScope(
            inbox: TrainerMessageInbox(
              totalUnread: 0,
              conversations: const [],
              contactUnread: count,
            ),
            child: const TrainerConversationsHub(
              initialContacts: true,
              students: Scaffold(body: Text('Chat de alumno')),
              contacts: Scaffold(body: Text('Chat de Isabel')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chat de Isabel').hitTestable(), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(Tab, 'Contactos'),
        matching: find.byType(Badge),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(Tab, 'Alumnos'),
        matching: find.byType(Badge),
      ),
      findsNothing,
    );
    unread.value = 0;
    await tester.pumpAndSettle();
    expect(find.byType(Badge), findsNothing);
    expect(find.text('Chat de Isabel').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    unread.dispose();
  });
}

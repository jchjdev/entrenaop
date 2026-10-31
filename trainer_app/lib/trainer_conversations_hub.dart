import 'package:flutter/material.dart';

import 'trainer_message_inbox_scope.dart';

/// Una entrada de navegación; cada pestaña conserva su lector y permisos.
class TrainerConversationsHub extends StatelessWidget {
  const TrainerConversationsHub({
    super.key,
    required this.students,
    required this.contacts,
    this.initialContacts = false,
  });
  final Widget students, contacts;
  final bool initialContacts;

  Widget _tab(String label, int unread) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (unread > 0) ...[
          const SizedBox(width: 8),
          Badge.count(count: unread),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final inbox = TrainerMessageInboxScope.of(context);
    return DefaultTabController(
      length: 2,
      initialIndex: initialContacts ? 1 : 0,
      child: Column(
        children: [
          Material(
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                _tab('Alumnos', inbox?.totalUnread ?? 0),
                _tab('Contactos', inbox?.contactUnread ?? 0),
              ],
            ),
          ),
          Expanded(child: TabBarView(children: [students, contacts])),
        ],
      ),
    );
  }
}

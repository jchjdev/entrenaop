import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_messages.dart';

/// Comparte una sola consulta de avisos con todas las tarjetas visibles.
class TrainerMessageInboxScope extends InheritedWidget {
  const TrainerMessageInboxScope({
    super.key,
    required this.inbox,
    required super.child,
  });
  final TrainerMessageInbox? inbox;
  static TrainerMessageInbox? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TrainerMessageInboxScope>()
      ?.inbox;
  static TrainerClientMessageSummary? client(
    BuildContext context,
    String clientId,
  ) => context
      .dependOnInheritedWidgetOfExactType<TrainerMessageInboxScope>()
      ?.inbox
      ?.clients[clientId];
  @override
  bool updateShouldNotify(TrainerMessageInboxScope oldWidget) =>
      oldWidget.inbox != inbox;
}

class TrainerClientMessageBadge extends StatelessWidget {
  const TrainerClientMessageBadge({
    super.key,
    required this.clientId,
    this.enabled = true,
  });
  final String clientId;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final summary = TrainerMessageInboxScope.client(context, clientId);
    if (summary == null || summary.unreadCount == 0) {
      return const SizedBox.shrink();
    }
    final count = summary.unreadCount;
    return IconButton(
      key: ValueKey('client-messages-$clientId'),
      tooltip:
          '$count ${count == 1 ? 'mensaje sin leer' : 'mensajes sin leer'}',
      onPressed: !enabled
          ? null
          : () => context.go('/conversations/${summary.relationId}'),
      icon: Badge.count(
        count: count,
        child: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }
}

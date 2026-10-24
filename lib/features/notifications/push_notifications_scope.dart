import 'package:flutter/material.dart';

import 'push_notifications.dart';

class PushNotificationsScope
    extends InheritedNotifier<PushNotificationCoordinator> {
  const PushNotificationsScope({
    super.key,
    required PushNotificationCoordinator? coordinator,
    required super.child,
  }) : super(notifier: coordinator);
  static PushNotificationCoordinator? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PushNotificationsScope>()
      ?.notifier;
  static PushNotificationCoordinator? readOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PushNotificationsScope>()?.notifier;
}

class StudentPushSettings extends StatelessWidget {
  const StudentPushSettings({super.key});
  @override
  Widget build(BuildContext context) {
    final push = PushNotificationsScope.maybeOf(context);
    if (push == null || !push.available || !push.serverAvailable) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avisos del preparador'),
            subtitle: Text(
              push.denied
                  ? 'Permite las notificaciones en los ajustes del teléfono y vuelve a comprobarlo.'
                  : 'Mensajes, formularios y cambios de planificación.',
            ),
            value: push.enabled,
            onChanged: push.busy
                ? null
                : (on) {
                    on ? push.enable() : push.disable();
                  },
          ),
          if (push.busy) const LinearProgressIndicator(),
          if (push.error case final error?) ...[
            Text(error),
            TextButton(
              onPressed: push.busy ? null : push.refresh,
              child: const Text('Comprobar avisos'),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:entrenaop/features/notifications/push_notifications_scope.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileNotificationsPage extends StatelessWidget {
  const ProfileNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final push = PushNotificationsScope.maybeOf(context);
    final ready = push != null && push.available && push.serverAvailable;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        leading: BackButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/profile/settings'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EntrenaCard(
                      tone: EntrenaCardTone.quiet,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notifications_none_rounded),
                          const SizedBox(height: 12),
                          Text(
                            'Tus avisos, a tu ritmo',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Gestiona los avisos del preparador, los recordatorios de entrenamiento y el horario de descanso.',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Las novedades del preparador siguen disponibles en Preparador, aunque no recibas avisos en el teléfono.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (ready)
                      const StudentPushSettings()
                    else
                      EntrenaCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (push?.busy == true) ...[
                              const LinearProgressIndicator(),
                              const SizedBox(height: 12),
                              const Text('Comprobando los avisos…'),
                            ] else ...[
                              Text(
                                push?.available == true
                                    ? 'Los avisos del teléfono no están disponibles en este momento.'
                                    : 'Los avisos del teléfono no están disponibles en esta instalación.',
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Puedes seguir consultando tus sesiones y mensajes en la app.',
                              ),
                              if (push?.available == true &&
                                  push?.accountId != null) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: push!.refresh,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Comprobar avisos'),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

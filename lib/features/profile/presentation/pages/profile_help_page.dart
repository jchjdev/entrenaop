import 'package:entrenaop/core/presentation/widgets/entrena_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileHelpPage extends StatelessWidget {
  const ProfileHelpPage({super.key});

  static const _topics =
      <({String question, String answer, String action, String route})>[
        (
          question: '¿Qué son la preparación y el plan adaptativo?',
          answer: 'Tu preparación reúne el objetivo, las pruebas y tus marcas. Su plan adaptativo organiza los entrenamientos y puede ajustar la continuidad con los resultados que registres. En Entrenar puedes consultar su estado y revisar lo que necesite tu atención.',
          action: 'Ver mi preparación',
          route: '/plan',
        ),
        (
          question: '¿Qué son los Programas?',
          answer: 'Son conjuntos de sesiones para seguir una rutina o un recorrido por fases. Puedes repetir una rutina o avanzar de fase siguiendo sus indicaciones. No se adaptan automáticamente como el plan de una preparación.',
          action: 'Explorar Programas',
          route: '/library?tab=programs',
        ),
        (
          question: '¿Puedo ver una sesión sin empezarla?',
          answer: 'Sí. Ver entrenamiento abre lo pautado sin crear una sesión en curso. Puedes revisar los ejercicios, las series y sus indicaciones. El entrenamiento empieza cuando pulsas Comenzar.',
          action: 'Ir a Entrenar',
          route: '/plan',
        ),
        (
          question: '¿Qué ocurre si dejo de tener Pro?',
          answer: 'Conservas la consulta del plan y tu historial. Empezar nuevos entrenamientos adaptativos, generar o adaptar el plan requiere Pro vigente. Si una sesión ya estaba empezada, puedes continuarla y terminarla. Las sesiones personales, la Biblioteca y lo pautado por tu preparador mantienen sus propias condiciones de acceso.',
          action: 'Ver EntrenaOP Pro',
          route: '/pro/subscription',
        ),
        (
          question: '¿Necesito un preparador?',
          answer: 'Puedes utilizar una preparación adaptativa sin contratar un preparador. El servicio de un preparador y EntrenaOP Pro son independientes. Si tienes preparador, encontrarás sus indicaciones, mensajes y sesiones en su espacio y en tu agenda.',
          action: 'Consultar mi preparación',
          route: '/plan',
        ),
        (
          question: '¿Cómo conecto mis dispositivos?',
          answer: 'Abre Dispositivos y conexiones desde Perfil. Allí se muestran las opciones disponibles de Salud, Garmin y relojes. Las funciones y permisos dependen del dispositivo: conectar un reloj no significa que todas las sesiones se envíen o se completen automáticamente.',
          action: 'Ver dispositivos y conexiones',
          route: '/profile/connections',
        ),
      ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ayuda'),
      leading: BackButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/profile/settings'),
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
                  Text(
                    'Preguntas frecuentes',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Resuelve tus dudas y vuelve a lo que estabas haciendo.',
                  ),
                  const SizedBox(height: 20),
                  for (final topic in _topics) ...[
                    EntrenaCard(
                      child: ExpansionTile(
                        key: PageStorageKey(topic.question),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        title: Text(topic.question),
                        children: [
                          Text(topic.answer),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.push(topic.route),
                            child: Text(topic.action),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  EntrenaCard(
                    tone: EntrenaCardTone.quiet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '¿Necesitas más ayuda?',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cuéntanos qué ha ocurrido para que podamos revisarlo.',
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/profile/settings/support'),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Informar de un problema'),
                        ),
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

import 'package:flutter/material.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:go_router/go_router.dart';

/// Mantiene visibles las áreas del alumno sin montar todos sus datos a la vez.
class TrainerClientNavigation extends StatelessWidget {
  const TrainerClientNavigation({
    super.key,
    required this.location,
    required this.child,
    this.isSelf = false,
  });
  final Uri location;
  final Widget child;
  final bool isSelf;

  static Widget wrap(Uri location, Widget child, {String? selfClientId}) {
    final parts = location.pathSegments;
    if (parts.length < 2 || parts.first != 'clients') return child;
    return TrainerClientNavigation(
      location: location,
      isSelf: parts[1] == selfClientId,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = location.pathSegments[1];
    final base = '/clients/${Uri.encodeComponent(id)}';
    final view = location.queryParameters['view'];
    final area = location.pathSegments.length == 2
        ? location.queryParameters['area'] ?? 'progress'
        : switch (location.pathSegments[2]) {
            'workouts' =>
              location.pathSegments.last == 'result'
                  ? 'results'
                  : view == 'technique'
                  ? 'technique'
                  : view == 'results'
                  ? 'results'
                  : 'planning',
            'forms' => 'forms',
            'goals' => 'goals',
            'results' => 'results',
            'technique' => 'technique',
            'conversation' => 'conversation',
            'calendar' => 'planning',
            _ => '',
          };
    final tabs = [
      ('planning', 'Planificación', '$base/workouts'),
      ('goals', 'Objetivos', '$base/goals'),
      ('results', 'Resultados', '$base/results'),
      ('technique', 'Técnica', '$base/technique'),
      ('progress', 'Evolución', '$base?area=progress'),
      ('forms', 'Formularios', '$base/forms'),
      if (!isSelf) ('conversation', 'Conversación', '$base/conversation'),
      ('notes', 'Notas', '$base?area=notes'),
      ('history', 'Historial', '$base?area=history'),
    ];
    return Column(
      // El Navigator bloquea semántica pintada antes: recorrer de abajo arriba
      // conserva la cabecera después del contenido sin cambiar su posición.
      verticalDirection: VerticalDirection.up,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: child),
        const Divider(height: 1),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Volver a alumnos',
                onPressed: () => context.go('/clients'),
                icon: const Icon(Icons.people_outline),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  child: Row(
                    children: [
                      for (final tab in tabs)
                        ProfessionalPageTab(
                          label: tab.$2,
                          selected: area == tab.$1,
                          onPressed: () {
                            if (location.toString() != tab.$3) {
                              context.go(tab.$3);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Más opciones del alumno',
                onSelected: (path) => context.go(path),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: '$base/workouts',
                    child: const Text('Calendario conjunto'),
                  ),
                  PopupMenuItem(
                    value: '$base/assessments',
                    child: const Text('Pruebas y simulacros'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

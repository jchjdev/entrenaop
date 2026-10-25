import 'package:flutter/material.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:go_router/go_router.dart';

/// Mantiene visibles las áreas del alumno sin montar todos sus datos a la vez.
class TrainerClientNavigation extends StatelessWidget {
  const TrainerClientNavigation({
    super.key,
    required this.location,
    required this.child,
  });
  final Uri location;
  final Widget child;

  static Widget wrap(Uri location, Widget child) {
    final parts = location.pathSegments;
    if (parts.length < 2 || parts.first != 'clients') return child;
    return TrainerClientNavigation(location: location, child: child);
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
            'conversation' => 'conversation',
            'calendar' => 'planning',
            _ => '',
          };
    final tabs = [
      ('planning', 'Planificación', '$base/workouts'),
      ('results', 'Resultados', '$base/workouts?view=results'),
      ('technique', 'Técnica', '$base/workouts?view=technique'),
      ('progress', 'Evolución', '$base?area=progress'),
      ('forms', 'Formularios', '$base/forms'),
      ('conversation', 'Conversación', '$base/conversation'),
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
                    value: '$base/calendar',
                    child: const Text('Calendario compartido'),
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

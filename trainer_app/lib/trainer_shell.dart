import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Los formularios mantienen toda la pantalla y su guard de salida propio.
class TrainerShell extends StatelessWidget {
  const TrainerShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  static const destinations = [
    ('/home', 'Inicio', Icons.home_outlined),
    ('/clients', 'Alumnos', Icons.people_outline),
    ('/agenda', 'Agenda', Icons.calendar_month_outlined),
    ('/workouts', 'Sesiones', Icons.fitness_center),
    ('/programs', 'Programas', Icons.view_week_outlined),
    ('/exercises', 'Ejercicios', Icons.sports_gymnastics),
    ('/reviews', 'Revisiones', Icons.fact_check_outlined),
    ('/forms', 'Formularios', Icons.assignment_outlined),
    ('/assessments', 'Pruebas y simulacros', Icons.timer_outlined),
    ('/groups', 'Grupos', Icons.groups_outlined),
    ('/media', 'Vídeos', Icons.video_library_outlined),
    ('/recurrence', 'Programar semanas', Icons.event_repeat_outlined),
  ];
  @override
  Widget build(BuildContext context) {
    if (location.endsWith('/new') ||
        location.endsWith('/revise') ||
        location.endsWith('/adapt')) {
      return child;
    }
    final index = destinations.indexWhere((d) => location.startsWith(d.$1));
    final selected = index >= 0
        ? index
        : destinations.indexWhere(
            (d) =>
                d.$1 ==
                (location.startsWith('/conversations/')
                    ? '/clients'
                    : '/agenda'),
          );
    void go(int value) {
      if (value != selected) context.go(destinations[value].$1);
    }

    Future<void> more() async {
      final destination = await showModalBottomSheet<int>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var i = 4; i < destinations.length; i++)
                ListTile(
                  leading: Icon(destinations[i].$3),
                  title: Text(destinations[i].$2),
                  selected: selected == i,
                  onTap: () => Navigator.pop(sheetContext, i),
                ),
            ],
          ),
        ),
      );
      if (destination != null && context.mounted) go(destination);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100 &&
            MediaQuery.textScalerOf(context).scale(16) < 24) {
          return Scaffold(
            body: Stack(
              children: [
                const SizedBox.expand(),
                Padding(
                  padding: const EdgeInsets.only(left: 256),
                  child: child,
                ),
                // El Navigator contiene BlockSemantics. Pintar la navegación
                // después conserva sus destinos para lectores de pantalla.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 256,
                  child: Material(
                    child: SafeArea(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Preparadores'),
                          ),
                          for (var i = 0; i < destinations.length; i++)
                            ListTile(
                              selected: selected == i,
                              selectedTileColor: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              leading: Icon(destinations[i].$3),
                              title: Text(destinations[i].$2),
                              onTap: () => go(i),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 255,
                  top: 0,
                  bottom: 0,
                  child: VerticalDivider(width: 1),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: child,
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < 5; i++)
                    Expanded(
                      child: TextButton(
                        onPressed: i == 4 ? more : () => go(i),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 8,
                          ),
                          backgroundColor:
                              (i == selected || (i == 4 && selected >= 4))
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              i == 4 ? Icons.more_horiz : destinations[i].$3,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                i == 4 ? 'Más' : destinations[i].$2,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

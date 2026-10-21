import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Los formularios mantienen toda la pantalla y su guard de salida propio.
class TrainerShell extends StatelessWidget {
  const TrainerShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  static const destinations = [
    ('/clients', 'Alumnos', Icons.people_outline),
    ('/agenda', 'Agenda', Icons.calendar_month_outlined),
    ('/workouts', 'Sesiones', Icons.fitness_center),
    ('/programs', 'Programas', Icons.view_week_outlined),
  ];
  @override
  Widget build(BuildContext context) {
    if (location.endsWith('/new') || location.endsWith('/revise')) return child;
    final index = destinations.indexWhere((d) => location.startsWith(d.$1));
    final selected = index < 0 ? 0 : index;
    void go(int value) {
      if (value != selected) context.go(destinations[value].$1);
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
                  child: NavigationRail(
                    extended: true,
                    minExtendedWidth: 256,
                    selectedLabelTextStyle: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                    selectedIndex: selected,
                    onDestinationSelected: go,
                    leading: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Preparadores'),
                    ),
                    destinations: [
                      for (final item in destinations)
                        NavigationRailDestination(
                          icon: Icon(item.$3),
                          label: Text(item.$2),
                        ),
                    ],
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
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: TextButton(
                        onPressed: () => go(i),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 8,
                          ),
                          backgroundColor: i == selected
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(destinations[i].$3),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  destinations[i].$2,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(fontSize: 12),
                                ),
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

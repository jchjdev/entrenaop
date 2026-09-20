import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _selectDestination(int index) {
    navigationShell.goBranch(
      index,
      // Al pulsar de nuevo la pestaña activa volvemos a su raíz, igual que en
      // las aplicaciones móviles habituales.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Scaffold(
            backgroundColor: const Color(0xFF0A0A0A),
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    backgroundColor: const Color(0xFF111111),
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: _selectDestination,
                    extended: constraints.maxWidth >= 1180,
                    labelType: constraints.maxWidth >= 1180
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.selected,
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    destinations: _railDestinations,
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _selectDestination,
            destinations: _barDestinations,
          ),
        );
      },
    );
  }
}

const _barDestinations = [
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home_rounded),
    label: 'Inicio',
  ),
  NavigationDestination(
    icon: Icon(Icons.event_note_outlined),
    selectedIcon: Icon(Icons.event_note_rounded),
    label: 'Mi plan',
  ),
  NavigationDestination(
    icon: Icon(Icons.insights_outlined),
    selectedIcon: Icon(Icons.insights_rounded),
    label: 'Evolución',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline_rounded),
    selectedIcon: Icon(Icons.person_rounded),
    label: 'Perfil',
  ),
];

const _railDestinations = [
  NavigationRailDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home_rounded),
    label: Text('Inicio'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.event_note_outlined),
    selectedIcon: Icon(Icons.event_note_rounded),
    label: Text('Mi plan'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.insights_outlined),
    selectedIcon: Icon(Icons.insights_rounded),
    label: Text('Evolución'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.person_outline_rounded),
    selectedIcon: Icon(Icons.person_rounded),
    label: Text('Perfil'),
  ),
];

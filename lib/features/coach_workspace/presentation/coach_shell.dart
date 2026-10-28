import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'coach_workspace_scope.dart';

class CoachShell extends StatelessWidget {
  const CoachShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  @override
  Widget build(BuildContext context) {
    final unread = CoachWorkspaceScope.of(context).controller.unread;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Resumen',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Agenda',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Alumnos',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            label: 'Mensajes',
          ),
        ],
      ),
    );
  }
}

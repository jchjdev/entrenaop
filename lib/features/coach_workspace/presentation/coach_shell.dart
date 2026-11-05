import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'coach_workspace_scope.dart';
import '../../../core/navigation/section_navigation_controller.dart';

class CoachShell extends StatefulWidget {
  const CoachShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  State<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends State<CoachShell> {
  late final _sectionNavigation = SectionNavigationController(
    rootLocations: const {
      '/coach',
      '/coach/agenda',
      '/coach/clients',
      '/coach/messages',
    },
    navigationShell: () => widget.navigationShell,
  );

  @override
  Widget build(BuildContext context) {
    final unread = CoachWorkspaceScope.of(context).controller.unread;
    return NotificationListener<Notification>(
      onNotification: (notification) =>
          _sectionNavigation.observeScroll(context, notification),
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) =>
              _sectionNavigation.selectDestination(context, index),
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
      ),
    );
  }
}

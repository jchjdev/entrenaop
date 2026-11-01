import '../../features/coach_workspace/presentation/coach_workspace_scope.dart';
import '../../features/coach_workspace/presentation/coach_mobile_style.dart';
import '../../features/trainers/presentation/student_navigation.dart';

import 'package:entrenaop/core/presentation/widgets/entrena_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'workspace_navigation_scope.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _selectDestination(int index) {
    navigationShell.goBranch(
      index,
      // Cambiar de sección conserva su pantalla; volver a pulsar la pestaña
      // activa regresa a su raíz. Las tareas de edición requieren otra frontera.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final professional = navigationShell.currentIndex == 5;
    final workspace = CoachWorkspaceScope.maybeOf(context)?.controller;
    final studentUnread =
        StudentNavigationScope.maybeOf(context)?.unreadCount ?? 0;
    if (!professional &&
        navigationShell.currentIndex != 3 &&
        workspace != null) {
      workspace.athleteIndex = navigationShell.currentIndex;
    }
    Widget frame(Widget child) => WorkspaceNavigationScope(
      enterProfessional: () {
        if (workspace?.enabled == true) navigationShell.goBranch(5);
      },
      returnToAthlete: () =>
          navigationShell.goBranch(workspace?.athleteIndex ?? 3),
      child: child,
    );

    if (professional) {
      return Theme(
        data: coachMobileTheme(Theme.of(context)),
        child: frame(navigationShell),
      );
    }
    // Se conservan las ramas históricas y la profesional; solo cambia el orden
    // visible. Evolución y Perfil comparten la rama 3.
    const indices = [0, 1, 2, 4, 3];
    Widget trainerIcon(IconData icon) => Badge.count(
      count: studentUnread,
      maxCount: 99,
      isLabelVisible: studentUnread > 0,
      backgroundColor: Theme.of(context).colorScheme.primary,
      textColor: Theme.of(context).colorScheme.onPrimary,
      child: Icon(icon),
    );
    final professionalUnread = workspace?.enabled == true
        ? workspace!.unread
        : 0;
    final profileTooltip = professionalUnread > 0
        ? 'Perfil · $professionalUnread novedades en tu espacio de preparador'
        : 'Perfil';
    Widget profileIcon(IconData icon) => Semantics(
      label: professionalUnread > 0
          ? '$professionalUnread novedades en tu espacio de preparador'
          : null,
      child: Badge(
        isLabelVisible: professionalUnread > 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(icon),
      ),
    );
    final destinations = [
      ..._barDestinations.take(3),
      NavigationDestination(
        icon: trainerIcon(Icons.people_outline),
        selectedIcon: trainerIcon(Icons.people),
        label: 'Preparador',
        tooltip: studentUnread > 0
            ? 'Preparador · $studentUnread novedades sin leer'
            : 'Preparador',
      ),
      NavigationDestination(
        icon: profileIcon(Icons.account_circle_outlined),
        selectedIcon: profileIcon(Icons.account_circle),
        label: 'Perfil',
        tooltip: profileTooltip,
      ),
    ];
    final selectedIndex = indices.indexOf(navigationShell.currentIndex);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return frame(
            Scaffold(
              body: Row(
                children: [
                  SafeArea(
                    child: NavigationRail(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) =>
                          _selectDestination(indices[index]),
                      extended: constraints.maxWidth >= 1180,
                      labelType: constraints.maxWidth >= 1180
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.selected,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: EntrenaWordmark(
                          width: constraints.maxWidth >= 1180 ? 132 : 58,
                        ),
                      ),
                      destinations: [
                        ..._railDestinations.take(3),
                        NavigationRailDestination(
                          icon: trainerIcon(Icons.people_outline),
                          selectedIcon: trainerIcon(Icons.people),
                          label: const Text('Preparador'),
                        ),
                        NavigationRailDestination(
                          icon: Tooltip(
                            message: profileTooltip,
                            excludeFromSemantics: true,
                            child: profileIcon(Icons.account_circle_outlined),
                          ),
                          selectedIcon: Tooltip(
                            message: profileTooltip,
                            excludeFromSemantics: true,
                            child: profileIcon(Icons.account_circle),
                          ),
                          label: const Text('Perfil'),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  // El Navigator de cada rama no debe ocultar a lectores de
                  // pantalla la navegación lateral situada a su lado.
                  Expanded(
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      child: navigationShell,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final labelStyle = _barLabelStyle(
          context,
          constraints.maxWidth,
          destinations,
        );
        return frame(
          Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              labelPadding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              labelTextStyle: labelStyle,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  _selectDestination(indices[index]),
              destinations: destinations,
            ),
          ),
        );
      },
    );
  }
}

WidgetStateProperty<TextStyle> _barLabelStyle(
  BuildContext context,
  double width,
  List<NavigationDestination> destinations,
) {
  final theme = Theme.of(context);
  TextStyle style(Set<WidgetState> states) => theme.textTheme.labelMedium!
      .merge(theme.navigationBarTheme.labelTextStyle?.resolve(states))
      .copyWith(letterSpacing: 0);
  final selected = style({WidgetState.selected});
  final baseSize = selected.fontSize!;
  final available = width / destinations.length - 12;
  final painter = TextPainter(
    textDirection: Directionality.of(context),
    // Mantener el límite nativo de NavigationBar sin reducir el texto de
    // las páginas. Reservar margen evita que las etiquetas se toquen.
    textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
    maxLines: 1,
  );
  var widest = 0.0;
  for (final destination in destinations) {
    painter.text = TextSpan(text: destination.label, style: selected);
    painter.layout();
    if (painter.width > widest) widest = painter.width;
  }
  painter.dispose();
  final fontSize = widest > available
      ? baseSize * (available - 1) / widest
      : baseSize;
  return WidgetStateProperty.resolveWith(
    (states) => style(states).copyWith(fontSize: fontSize),
  );
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
    label: 'Entrenar',
  ),
  NavigationDestination(
    icon: Icon(Icons.library_books_outlined),
    selectedIcon: Icon(Icons.library_books_rounded),
    label: 'Biblioteca',
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
    label: Text('Entrenar'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.library_books_outlined),
    selectedIcon: Icon(Icons.library_books_rounded),
    label: Text('Biblioteca'),
  ),
];

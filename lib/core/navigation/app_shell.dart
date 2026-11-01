import '../../features/coach_workspace/presentation/coach_workspace_scope.dart';
import '../../features/coach_workspace/presentation/coach_mobile_style.dart';
import '../../features/trainers/presentation/student_navigation.dart';

import 'package:entrenaop/core/presentation/widgets/entrena_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    if (!professional && workspace != null) {
      workspace.athleteIndex = navigationShell.currentIndex;
    }
    Widget frame(Widget child) {
      if (workspace == null || (!workspace.enabled && !professional)) {
        return child;
      }
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Flexible(
                      child: _WorkspaceSwitcher(
                        professional: professional,
                        unread: workspace.unread,
                        onSelected: (selected) {
                          if (selected == professional) return;
                          navigationShell.goBranch(
                            selected ? 5 : workspace.athleteIndex,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }

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
      _barDestinations.last,
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
                        _railDestinations.last,
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: navigationShell),
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

class _WorkspaceSwitcher extends StatelessWidget {
  const _WorkspaceSwitcher({
    required this.professional,
    required this.unread,
    required this.onSelected,
  });
  final bool professional;
  final int unread;
  final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('app-workspace-switcher'),
    color: Colors.transparent,
    child: LayoutBuilder(
      builder: (context, size) {
        // Con texto grande se cambia el patrón, no la preferencia de accesibilidad.
        // El menú conserva los nombres completos sin partirlos entre segmentos.
        if (size.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.15) {
          return PopupMenuButton<bool>(
            tooltip: unread > 0
                ? 'Cambiar espacio · $unread novedades en Entrenador'
                : 'Cambiar espacio',
            initialValue: professional,
            onSelected: onSelected,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: false,
                child: Text('Mi entrenamiento'),
              ),
              PopupMenuItem(
                value: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(child: Text('Entrenador')),
                    if (unread > 0) ...[
                      const SizedBox(width: 12),
                      Badge.count(count: unread),
                    ],
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      professional ? 'Entrenador' : 'Personal',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (professional && unread > 0) ...[
                    const SizedBox(width: 8),
                    Semantics(
                      label: '$unread novedades en Entrenador',
                      child: Badge.count(count: unread),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Badge(
                    // En Personal el punto indica novedades en el otro espacio;
                    // su total pertenece a Entrenador y se muestra en el menú.
                    isLabelVisible: !professional && unread > 0,
                    child: const Icon(Icons.expand_more, size: 22),
                  ),
                ],
              ),
            ),
          );
        }
        return SegmentedButton<bool>(
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            minimumSize: WidgetStatePropertyAll(Size(0, 44)),
          ),
          segments: [
            const ButtonSegment(value: false, label: Text('Personal')),
            ButtonSegment(
              value: true,
              icon: unread > 0 ? Badge.count(count: unread) : null,
              label: const Text('Entrenador'),
            ),
          ],
          selected: {professional},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onSelected(selection.single),
        );
      },
    ),
  );
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
  NavigationDestination(
    icon: Icon(Icons.account_circle_outlined),
    selectedIcon: Icon(Icons.account_circle),
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
    label: Text('Entrenar'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.library_books_outlined),
    selectedIcon: Icon(Icons.library_books_rounded),
    label: Text('Biblioteca'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.account_circle_outlined),
    selectedIcon: Icon(Icons.account_circle),
    label: Text('Perfil'),
  ),
];

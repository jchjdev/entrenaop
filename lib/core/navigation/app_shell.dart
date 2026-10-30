import '../../features/coach_workspace/presentation/coach_workspace_scope.dart';
import '../../features/coach_workspace/presentation/coach_mobile_style.dart';

import 'package:entrenaop/core/presentation/widgets/entrena_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/trainers/presentation/student_navigation.dart';

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
                    Expanded(
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
                    if (professional)
                      IconButton(
                        tooltip: 'Mi perfil',
                        onPressed: () => context.push('/profile'),
                        icon: const Icon(Icons.account_circle_outlined),
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
    final showTrainer =
        StudentNavigationScope.maybeOf(context)?.hasTrainer == true ||
        navigationShell.currentIndex == 4;
    final indices = [0, 1, 2, 3, if (showTrainer) 4];
    final destinations = [
      ..._barDestinations.take(4),
      if (showTrainer) _barDestinations.last,
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
                        ..._railDestinations.take(4),
                        if (showTrainer) _railDestinations.last,
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
            tooltip: 'Cambiar espacio',
            initialValue: professional,
            onSelected: onSelected,
            itemBuilder: (_) => const [
              PopupMenuItem(value: false, child: Text('Mi entrenamiento')),
              PopupMenuItem(value: true, child: Text('Entrenador')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      professional ? 'Entrenador' : 'Personal',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    Badge.count(count: unread),
                  ],
                  const SizedBox(width: 8),
                  const Icon(Icons.expand_more, size: 22),
                ],
              ),
            ),
          );
        }
        return SegmentedButton<bool>(
          segments: [
            const ButtonSegment(value: false, label: Text('Mi entrenamiento')),
            ButtonSegment(
              value: true,
              label: Badge.count(
                count: unread,
                isLabelVisible: unread > 0,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Entrenador'),
                ),
              ),
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
    label: 'Mi plan',
  ),
  NavigationDestination(
    icon: Icon(Icons.library_books_outlined),
    selectedIcon: Icon(Icons.library_books_rounded),
    label: 'Biblioteca',
  ),
  NavigationDestination(
    icon: Icon(Icons.insights_outlined),
    selectedIcon: Icon(Icons.insights_rounded),
    label: 'Evolución',
  ),
  NavigationDestination(
    icon: Icon(Icons.people_outline),
    selectedIcon: Icon(Icons.people),
    label: 'Preparador',
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
    icon: Icon(Icons.library_books_outlined),
    selectedIcon: Icon(Icons.library_books_rounded),
    label: Text('Biblioteca'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.insights_outlined),
    selectedIcon: Icon(Icons.insights_rounded),
    label: Text('Evolución'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.people_outline),
    selectedIcon: Icon(Icons.people),
    label: Text('Preparador'),
  ),
];

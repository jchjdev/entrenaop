import '../../features/coach_workspace/presentation/coach_workspace_scope.dart';
import '../../features/coach_workspace/presentation/coach_mobile_style.dart';
import '../../features/trainers/presentation/student_navigation.dart';

import 'package:entrenaop/core/presentation/widgets/entrena_wordmark.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
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
    // El orden de Pulso es visual. Evolución y Perfil comparten la rama 3.
    const mobileIndices = [0, 2, 1, 4, 3];
    const railIndices = [0, 1, 2, 4, 3];
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
        icon: _PulsoIcon(child: trainerIcon(Icons.people_outline)),
        selectedIcon: _PulsoIcon(child: trainerIcon(Icons.people)),
        label: 'Preparador',
        tooltip: studentUnread > 0
            ? 'Preparador · $studentUnread novedades sin leer'
            : 'Preparador',
      ),
      NavigationDestination(
        icon: _PulsoIcon(child: profileIcon(Icons.account_circle_outlined)),
        selectedIcon: _PulsoIcon(child: profileIcon(Icons.account_circle)),
        label: 'Perfil',
        tooltip: profileTooltip,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return frame(
            Scaffold(
              body: Row(
                children: [
                  SafeArea(
                    child: NavigationRail(
                      selectedIndex: railIndices.indexOf(
                        navigationShell.currentIndex,
                      ),
                      onDestinationSelected: (index) =>
                          _selectDestination(railIndices[index]),
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

        return frame(
          Scaffold(
            // Las portadas reservan el espacio de Pulso dentro del scroll.
            // Los detalles pueden tener acciones fijas al pie de la pantalla.
            extendBody: _pulsoOverlayRoutes.contains(
              GoRouterState.of(context).uri.path,
            ),
            body: navigationShell,
            bottomNavigationBar: _PulsoNavigationBar(
              selectedIndex: mobileIndices.indexOf(
                navigationShell.currentIndex,
              ),
              onDestinationSelected: (index) =>
                  _selectDestination(mobileIndices[index]),
              destinations: destinations,
            ),
          ),
        );
      },
    );
  }
}

const _pulsoOverlayRoutes = {
  '/home',
  '/library',
  '/plan',
  '/my-trainer',
  '/profile',
};

class _PulsoNavigationBar extends StatelessWidget {
  const _PulsoNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                top: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              NavigationBar(
                height: 76,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                elevation: 0,
                labelPadding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                labelTextStyle: _barLabelStyle(
                  context,
                  constraints.maxWidth,
                  destinations,
                ),
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                destinations: destinations,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 5,
                child: IgnorePointer(
                  child: Row(
                    children: [
                      for (var index = 0; index < destinations.length; index++)
                        Expanded(
                          child: Center(
                            child: index == selectedIndex
                                ? Container(
                                    width: 12,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: colors.secondary,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  )
                                : const SizedBox.shrink(),
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
  }
}

class _PulsoIcon extends StatelessWidget {
  const _PulsoIcon({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 36, child: Center(widthFactor: 1, child: child));
}

class _PulsoMark extends StatelessWidget {
  const _PulsoMark();

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(0, -7),
    child: Container(
      width: 42,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: EntrenaTheme.brandOrange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExcludeSemantics(
        child: Image.asset(
          'assets/branding/entrenaop_op_mark.png',
          key: const ValueKey('pulso-op-mark'),
          width: 30,
          color: const Color(0xFF220B03),
          filterQuality: FilterQuality.high,
        ),
      ),
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
      .copyWith(
        letterSpacing: 0,
        color: states.contains(WidgetState.selected)
            ? theme.colorScheme.secondary
            : theme.colorScheme.onSurfaceVariant,
      );
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
    icon: _PulsoIcon(child: Icon(Icons.home_outlined)),
    selectedIcon: _PulsoIcon(child: Icon(Icons.home_rounded)),
    label: 'Inicio',
  ),
  NavigationDestination(
    icon: _PulsoIcon(child: Icon(Icons.library_books_outlined)),
    selectedIcon: _PulsoIcon(child: Icon(Icons.library_books_rounded)),
    label: 'Biblioteca',
  ),
  NavigationDestination(icon: _PulsoMark(), label: 'Entrena'),
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

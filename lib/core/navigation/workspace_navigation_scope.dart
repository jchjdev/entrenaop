import 'package:flutter/material.dart';

/// Accesos de presentación a las pilas ya existentes. No concede permisos ni
/// sustituye las comprobaciones de acceso del espacio profesional.
class WorkspaceNavigationScope extends InheritedWidget {
  const WorkspaceNavigationScope({
    required this.enterProfessional,
    required this.returnToAthlete,
    required super.child,
    super.key,
  });

  final VoidCallback enterProfessional;
  final VoidCallback returnToAthlete;

  static WorkspaceNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceNavigationScope>();

  static WorkspaceNavigationScope of(BuildContext context) => maybeOf(context)!;

  @override
  bool updateShouldNotify(WorkspaceNavigationScope oldWidget) =>
      oldWidget.enterProfessional != enterProfessional ||
      oldWidget.returnToAthlete != returnToAthlete;
}

/// Vive en las cabeceras profesionales existentes, junto al retorno normal de
/// cada recorrido. Cambiar de espacio conserva su pila y sus borradores.
class WorkspaceReturnAction extends StatelessWidget {
  const WorkspaceReturnAction({super.key});

  @override
  Widget build(BuildContext context) {
    final navigation = WorkspaceNavigationScope.maybeOf(context);
    if (navigation == null) return const SizedBox.shrink();
    return IconButton(
      key: const ValueKey('workspace-return-to-athlete'),
      tooltip: 'Volver a mi entrenamiento',
      onPressed: navigation.returnToAthlete,
      icon: const Icon(Icons.directions_run_rounded),
    );
  }
}

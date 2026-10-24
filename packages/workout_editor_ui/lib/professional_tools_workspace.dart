import 'package:entrena_ui/floating_tool_workspace.dart';
import 'package:flutter/material.dart';

import 'running_pace_calculator_view.dart';

class ProfessionalToolsWorkspace extends StatelessWidget {
  const ProfessionalToolsWorkspace({required this.child, super.key});
  final Widget child;

  static void openCalculator(BuildContext context) =>
      FloatingToolWorkspace.openerOf(context)?.call();

  @override
  Widget build(BuildContext context) => FloatingToolWorkspace(
    title: 'Calculadora de ritmos',
    shortTitle: 'Ritmos',
    toolBuilder: (_) => const RunningPaceCalculatorView(compact: true),
    child: child,
  );
}

/// Abre una herramienta sobre la ruta actual sin activar los guards de salida.
class ProfessionalToolsButton extends StatelessWidget {
  const ProfessionalToolsButton({this.iconOnly = false, super.key});

  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final open = FloatingToolWorkspace.openerOf(context);
    if (open == null) return const SizedBox.shrink();
    final compact =
        iconOnly ||
        MediaQuery.sizeOf(context).width < 600 ||
        MediaQuery.textScalerOf(context).scale(16) >= 24;
    return PopupMenuButton<void>(
      tooltip: 'Herramientas',
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          onTap: open,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.speed),
            title: Text('Calculadora de ritmos'),
          ),
        ),
      ],
      child: compact
          ? const SizedBox.square(
              dimension: 48,
              child: Icon(Icons.calculate_outlined),
            )
          : const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calculate_outlined),
                  SizedBox(width: 8),
                  Text('Herramientas'),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';

/// Etiqueta discreta y control de elección. La letra ampliada conserva espacio
/// apilando la etiqueta, sin estrechar ni recortar el valor seleccionado.
class CompactFieldLayout extends StatelessWidget {
  const CompactFieldLayout({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final caption = Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          );
          final control = Semantics(label: label, child: child);
          if (constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(16) > 24) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [caption, const SizedBox(height: 6), control],
            );
          }
          return Row(
            children: [
              Expanded(child: caption),
              const SizedBox(width: 12),
              SizedBox(width: constraints.maxWidth * .65, child: control),
            ],
          );
        },
      ),
    ),
  );
}

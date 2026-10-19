import 'package:flutter/material.dart';

/// Columnas iguales solo cuando caben campos legibles con la escala de texto.
class ResponsiveFieldGroup extends StatelessWidget {
  const ResponsiveFieldGroup({
    super.key,
    required this.children,
    this.minimumFieldWidth = 180,
    this.spacing = 12,
    this.runSpacing = 16,
  });

  final List<Widget> children;
  final double minimumFieldWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minimum =
          minimumFieldWidth * MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns =
          children.length > 1 && constraints.maxWidth >= minimum * 2 + spacing
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * spacing) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: [
          for (final field in children) SizedBox(width: width, child: field),
        ],
      );
    },
  );
}

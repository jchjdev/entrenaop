import 'package:flutter/material.dart';

/// Columnas iguales solo cuando caben campos legibles con la escala de texto.
class ResponsiveFieldGroup extends StatelessWidget {
  const ResponsiveFieldGroup({
    super.key,
    required this.children,
    this.minimumFieldWidth = 144,
    this.maximumColumns = 2,
    this.spacing = 12,
    this.runSpacing = 16,
  });

  final List<Widget> children;
  final double minimumFieldWidth;
  final int maximumColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minimum =
          minimumFieldWidth * MediaQuery.textScalerOf(context).scale(16) / 16;
      var columns = 1;
      for (final candidate in [2, if (children.length == 3) 3, 4]) {
        if (candidate <= maximumColumns &&
            children.length >= candidate &&
            constraints.maxWidth >=
                minimum * candidate + spacing * (candidate - 1)) {
          columns = candidate;
        }
      }
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

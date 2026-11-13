import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'exercise_search_list.dart';

class ExerciseCatalogCard extends StatelessWidget {
  const ExerciseCatalogCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.actions,
    this.onTap,
  });

  final String? imageUrl;
  final String title, subtitle;
  final Widget? actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                actions == null ? 12 : 50,
                12,
                12,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    ExerciseThumbnail.catalog(
                      url: imageUrl,
                      width: math.min(128, constraints.maxWidth * 0.42),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (actions != null)
            PositionedDirectional(top: 2, end: 4, child: actions!),
        ],
      ),
    );
  }
}

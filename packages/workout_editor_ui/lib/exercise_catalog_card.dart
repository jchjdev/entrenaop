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
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    const actionSize = 48.0;
    const actionInset = 4.0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: actions == null ? 0 : 2 * actionSize + 2 * actionInset,
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: 12,
                  top: 12,
                  end: actions == null ? 12 : actionSize + actionInset + 4,
                  bottom: 12,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: [
                      ExerciseThumbnail.catalog(
                        url: imageUrl,
                        width: math.min(
                          128,
                          constraints.maxWidth * 0.48 / math.max(1, textScale),
                        ),
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
              PositionedDirectional(
                top: actionInset,
                end: actionInset,
                width: actionSize,
                child: actions!,
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'entrena_card.dart';
import 'entrena_theme.dart';

/// Composición editorial compartida por preparaciones y programas.
class EntrenaProgramCard extends StatelessWidget {
  const EntrenaProgramCard({
    super.key,
    required this.title,
    required this.label,
    required this.detail,
    required this.actionLabel,
    required this.icon,
    this.onTap,
    this.coverImage,
    this.focalX = 0.5,
    this.focalY = 0.5,
    this.categoryLabel,
  });
  final String title, label, detail, actionLabel;
  final IconData icon;
  final VoidCallback? onTap;
  final ImageProvider? coverImage;
  final double focalX, focalY;
  final String? categoryLabel;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final titleWidget = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 18,
        height: 1.2,
        fontWeight: FontWeight.w800,
      ),
    );
    return EntrenaCard(
      tone: EntrenaCardTone.progress,
      onTap: onTap,
      coverImage: coverImage,
      focalX: focalX,
      focalY: focalY,
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: secondary, size: 25),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.visuals.textMuted,
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (categoryLabel != null)
                      Tooltip(
                        message: categoryLabel!,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            categoryLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: secondary,
                              fontSize: 11,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          titleWidget,
          const SizedBox(height: 6),
          Text(
            detail,
            style: TextStyle(
              color: context.visuals.textMuted,
              fontSize: 13,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            actionLabel,
            style: TextStyle(
              color: secondary,
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

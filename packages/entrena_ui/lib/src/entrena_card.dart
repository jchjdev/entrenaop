import 'entrena_theme.dart';
import 'entrena_cover_image.dart';

import 'package:flutter/material.dart';

enum EntrenaCardTone { neutral, accent, progress, quiet }

/// Superficie de marca para las tarjetas que necesitan jerarquia propia.
///
/// Las tarjetas convencionales siguen usando [Card] y reciben el estilo del
/// tema global. Este componente queda reservado para contenido protagonista,
/// progreso y accesos importantes.
class EntrenaCard extends StatelessWidget {
  const EntrenaCard({
    required this.child,
    super.key,
    this.tone = EntrenaCardTone.neutral,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.accentColor,
    this.coverImage,
    this.coverImageUrl,
    this.focalX = 0.5,
    this.focalY = 0.5,
  });

  final Widget child;
  final EntrenaCardTone tone;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;
  final ImageProvider? coverImage;
  final String? coverImageUrl;
  final double focalX, focalY;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final background = Theme.of(context).scaffoldBackgroundColor;
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    final (:colors, :border) = switch (tone) {
      EntrenaCardTone.accent => (
        colors: [visuals.surfaceWarm, visuals.surfaceHigh],
        border: accent.withValues(alpha: 0.42),
      ),
      EntrenaCardTone.progress => (
        colors: [visuals.surfaceHigh, visuals.surface],
        border: visuals.outlineStrong,
      ),
      EntrenaCardTone.quiet => (
        colors: [visuals.surfaceLow, visuals.surfaceLow],
        border: visuals.outline,
      ),
      EntrenaCardTone.neutral => (
        colors: [visuals.surfaceHigh, visuals.surface],
        border: visuals.outline,
      ),
    };
    const radius = BorderRadius.all(Radius.circular(22));

    final content = Padding(padding: padding, child: child);

    return Material(
      color: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: radius,
          border: Border.all(color: border),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (coverImage != null || coverImageUrl != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      EntrenaCoverImage(
                        image: coverImage,
                        imageUrl: coverImageUrl,
                        focalX: focalX,
                        focalY: focalY,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              background.withValues(alpha: 0.94),
                              background.withValues(alpha: 0.86),
                              background.withValues(alpha: 0.38),
                            ],
                            stops: const [0, 0.45, 1],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              background.withValues(alpha: 0.72),
                              Colors.transparent,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (onTap == null)
              content
            else
              InkWell(onTap: onTap, child: content),
            if (tone != EntrenaCardTone.quiet)
              Positioned(
                right: 18,
                top: 0,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: -0.12,
                    child: Container(
                      width: 52,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.15)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

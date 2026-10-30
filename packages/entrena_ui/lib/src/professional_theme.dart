import 'package:flutter/material.dart';

import 'entrena_theme.dart';

/// Acabado de escritorio; el deportista conserva sus superficies táctiles.
@immutable
class ProfessionalSurfaceStyle
    extends ThemeExtension<ProfessionalSurfaceStyle> {
  const ProfessionalSurfaceStyle();
  @override
  ProfessionalSurfaceStyle copyWith() => this;
  @override
  ProfessionalSurfaceStyle lerp(ProfessionalSurfaceStyle? other, double t) =>
      other ?? this;
}

class ProfessionalAppearance extends StatelessWidget {
  const ProfessionalAppearance({
    super.key,
    required this.enabled,
    required this.child,
  });
  final bool enabled;
  final Widget child;

  static ThemeData desktop(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;
    final visuals = isDark ? EntrenaVisuals.dark : EntrenaVisuals.light;
    final background = isDark ? const Color(0xFF0B0E12) : visuals.surfaceLow;
    final surface = isDark ? const Color(0xFF151A21) : visuals.surface;
    final raised = isDark ? const Color(0xFF202833) : visuals.surfaceHigh;
    final line = isDark ? const Color(0xFF2B333F) : visuals.outline;
    final text = isDark ? const Color(0xFFEEF1F5) : base.colorScheme.onSurface;
    final muted = isDark ? const Color(0xFFAAB5C4) : visuals.textMuted;
    final orange = isDark ? const Color(0xFFFF6A32) : base.colorScheme.primary;
    final tint = isDark ? const Color(0xFF30221C) : visuals.accentSoft;
    final scheme = base.colorScheme.copyWith(
      primary: orange,
      secondary: orange,
      primaryContainer: tint,
      secondaryContainer: tint,
      onSurface: text,
      onSurfaceVariant: muted,
      surface: surface,
      surfaceContainerLowest: background,
      surfaceContainerLow: background,
      surfaceContainer: surface,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: raised,
      outline: line,
      outlineVariant: line,
    );
    final typography = base.textTheme
        .copyWith(
          headlineLarge: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          headlineMedium: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
          headlineSmall: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
          titleLarge: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
          titleMedium: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          titleSmall: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          bodyLarge: const TextStyle(fontSize: 14, height: 1.5),
          bodyMedium: const TextStyle(fontSize: 13, height: 1.5),
          bodySmall: const TextStyle(fontSize: 12, height: 1.4),
          labelLarge: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          labelSmall: const TextStyle(fontSize: 11, letterSpacing: .6),
        )
        .apply(
          fontFamily: base.textTheme.bodyMedium?.fontFamily ?? 'Roboto',
          bodyColor: text,
          displayColor: text,
        )
        .copyWith(
          bodySmall: base.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: muted,
            height: 1.4,
          ),
        );
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(6)),
    );
    ButtonStyle button(Color foreground, Color color) => TextButton.styleFrom(
      foregroundColor: foreground,
      backgroundColor: color,
      minimumSize: const Size(36, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      textStyle: typography.labelLarge,
      iconSize: 17,
      shape: shape,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final input = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: line),
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: scheme,
      textTheme: typography,
      dividerColor: line,
      iconTheme: IconThemeData(size: 18, color: muted),
      extensions: [
        for (final extension in base.extensions.values)
          if (extension is! EntrenaVisuals &&
              extension is! ProfessionalSurfaceStyle)
            extension,
        visuals.copyWith(
          surfaceLow: background,
          surface: surface,
          surfaceHigh: raised,
          surfaceWarm: tint,
          accentSoft: tint,
          outline: line,
          outlineStrong: line,
          textMuted: muted,
        ),
        const ProfessionalSurfaceStyle(),
      ],
      appBarTheme: base.appBarTheme.copyWith(
        toolbarHeight: 52,
        titleTextStyle: typography.titleLarge,
        backgroundColor: background,
        foregroundColor: text,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: surface,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button(
          isDark ? scheme.onPrimary : const Color(0xFF220B03),
          isDark ? orange : EntrenaTheme.brandOrange,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: button(
          text,
          surface,
        ).copyWith(elevation: const WidgetStatePropertyAll(0)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button(
          text,
          surface,
        ).copyWith(side: WidgetStatePropertyAll(BorderSide(color: line))),
      ),
      textButtonTheme: TextButtonThemeData(
        style: button(text, Colors.transparent),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          iconSize: 18,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        dense: true,
        minTileHeight: 38,
        minLeadingWidth: 20,
        horizontalTitleGap: 10,
        titleTextStyle: typography.bodyMedium,
        subtitleTextStyle: typography.bodySmall,
        iconColor: muted,
        selectedColor: orange,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: background,
        labelStyle: typography.bodySmall,
        floatingLabelStyle: typography.bodySmall,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: input,
        enabledBorder: input,
        focusedBorder: input.copyWith(borderSide: BorderSide(color: orange)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: raised,
        selectedColor: tint,
        shape: const StadiumBorder(),
        side: BorderSide.none,
        labelStyle: typography.bodySmall,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: enabled ? desktop(Theme.of(context)) : Theme.of(context),
    child: child,
  );
}

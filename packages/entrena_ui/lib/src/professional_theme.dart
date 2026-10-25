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
    const background = Color(0xFF0B0E12),
        surface = Color(0xFF151A21),
        raised = Color(0xFF202833);
    const line = Color(0xFF2B333F),
        text = Color(0xFFEEF1F5),
        muted = Color(0xFFAAB5C4);
    const orange = Color(0xFFFF6A32), tint = Color(0xFF30221C);
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
      borderSide: const BorderSide(color: line),
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: scheme,
      textTheme: typography,
      dividerColor: line,
      iconTheme: const IconThemeData(size: 18, color: muted),
      extensions: [
        for (final extension in base.extensions.values)
          if (extension is! EntrenaVisuals &&
              extension is! ProfessionalSurfaceStyle)
            extension,
        EntrenaVisuals.dark.copyWith(
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button(scheme.onPrimary, orange),
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
        ).copyWith(side: const WidgetStatePropertyAll(BorderSide(color: line))),
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
        focusedBorder: input.copyWith(
          borderSide: const BorderSide(color: orange),
        ),
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

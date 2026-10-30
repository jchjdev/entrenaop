import 'package:flutter/material.dart';

/// Identidad visual compartida por la aplicación del deportista y el panel admin.
///
/// Material 3 sigue resolviendo comportamiento y accesibilidad. Estos tokens
/// aportan la personalidad de EntrenaOP sin repartir colores y medidas por las
/// pantallas.
@immutable
class EntrenaVisuals extends ThemeExtension<EntrenaVisuals> {
  const EntrenaVisuals({
    required this.surfaceLow,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceWarm,
    required this.outline,
    required this.outlineStrong,
    required this.accentSoft,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.info,
  });

  final Color surfaceLow;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceWarm;
  final Color outline;
  final Color outlineStrong;
  final Color accentSoft;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color info;

  static const dark = EntrenaVisuals(
    surfaceLow: Color(0xFF0D0F12),
    surface: Color(0xFF13161B),
    surfaceHigh: Color(0xFF1A1E24),
    surfaceWarm: Color(0xFF24140F),
    outline: Color(0xFF2A2F37),
    outlineStrong: Color(0xFF3A414C),
    accentSoft: Color(0xFF3A1B10),
    textMuted: Color(0xFFA9A6A3),
    success: Color(0xFF67D391),
    warning: Color(0xFFFFB45E),
    info: Color(0xFF7CC5FF),
  );

  static const light = EntrenaVisuals(
    surfaceLow: Color(0xFFF4F6F9),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE9EEF4),
    surfaceWarm: Color(0xFFFFF1E8),
    outline: Color(0xFFD4DAE3),
    outlineStrong: Color(0xFF8793A3),
    accentSoft: Color(0xFFFFE9DC),
    textMuted: Color(0xFF4D5B6B),
    success: Color(0xFF17663F),
    warning: Color(0xFF805000),
    info: Color(0xFF155B87),
  );

  @override
  EntrenaVisuals copyWith({
    Color? surfaceLow,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceWarm,
    Color? outline,
    Color? outlineStrong,
    Color? accentSoft,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? info,
  }) => EntrenaVisuals(
    surfaceLow: surfaceLow ?? this.surfaceLow,
    surface: surface ?? this.surface,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    surfaceWarm: surfaceWarm ?? this.surfaceWarm,
    outline: outline ?? this.outline,
    outlineStrong: outlineStrong ?? this.outlineStrong,
    accentSoft: accentSoft ?? this.accentSoft,
    textMuted: textMuted ?? this.textMuted,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    info: info ?? this.info,
  );

  @override
  EntrenaVisuals lerp(EntrenaVisuals? other, double t) {
    if (other == null) return this;
    return EntrenaVisuals(
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceWarm: Color.lerp(surfaceWarm, other.surfaceWarm, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

extension EntrenaThemeContext on BuildContext {
  EntrenaVisuals get visuals =>
      Theme.of(this).extension<EntrenaVisuals>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? EntrenaVisuals.dark
          : EntrenaVisuals.light);

  /// Mantiene el matiz del calendario/formato y oscurece solo los acentos claros.
  Color readableAccent(Color color) {
    final theme = Theme.of(this);
    if (theme.brightness == Brightness.dark) return color;
    final background = theme.colorScheme.surface.computeLuminance();
    final hsl = HSLColor.fromColor(color);
    var result = color;
    for (var step = 0; step < 30; step++) {
      final ink = result.computeLuminance();
      final ratio = background > ink
          ? (background + .05) / (ink + .05)
          : (ink + .05) / (background + .05);
      if (ratio >= 5.5) break;
      result = hsl
          .withLightness((hsl.lightness - (step + 1) * .03).clamp(0.0, 1.0))
          .toColor();
    }
    return result;
  }
}

abstract final class EntrenaTheme {
  static const brandOrange = Color(0xFFFF5A1F);
  static const brandOrangeLight = Color(0xFFFF8A50);
  static const canvas = Color(0xFF090A0D);
  static const ink = Color(0xFF17191D);
  static const textPrimary = Color(0xFFF5F3F0);

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final visuals = isDark ? EntrenaVisuals.dark : EntrenaVisuals.light;
    final background = isDark ? canvas : visuals.surfaceLow;
    final textColor = isDark ? textPrimary : const Color(0xFF17212F);
    final accentForeground = isDark
        ? brandOrangeLight
        : const Color(0xFFAE350A);
    final iconColor = isDark ? const Color(0xFFD8D6D2) : visuals.textMuted;
    final highest = isDark ? const Color(0xFF242A32) : const Color(0xFFE0E7EF);
    final dialogSurface = isDark ? const Color(0xFF15181D) : visuals.surface;
    final dialogOutline = isDark ? const Color(0xFF343A44) : visuals.outline;
    final progressTrack = isDark ? const Color(0xFF2A1A14) : visuals.accentSoft;
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: brandOrange,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? brandOrange : accentForeground,
          onPrimary: isDark ? const Color(0xFF220B03) : Colors.white,
          secondary: accentForeground,
          onSecondary: isDark ? const Color(0xFF220B03) : Colors.white,
          primaryContainer: visuals.accentSoft,
          onPrimaryContainer: accentForeground,
          secondaryContainer: visuals.accentSoft,
          onSecondaryContainer: textColor,
          surface: visuals.surface,
          surfaceContainerLowest: background,
          surfaceContainerLow: visuals.surfaceLow,
          surfaceContainer: visuals.surface,
          surfaceContainerHigh: visuals.surfaceHigh,
          surfaceContainerHighest: highest,
          onSurface: textColor,
          onSurfaceVariant: visuals.textMuted,
          outline: visuals.outlineStrong,
          outlineVariant: visuals.outline,
          surfaceTint: Colors.transparent,
        );

    final textTheme = base.textTheme
        .copyWith(
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.9,
            height: 1.08,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            height: 1.1,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.25,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        )
        .apply(bodyColor: textColor, displayColor: textColor);

    final roundedCard = RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      side: BorderSide(color: visuals.outline),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: visuals.outline,
      shadowColor: isDark
          ? base.shadowColor
          : Colors.black.withValues(alpha: .14),
      textTheme: textTheme,
      iconTheme: IconThemeData(color: iconColor),
      extensions: <ThemeExtension<dynamic>>[visuals],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: visuals.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: roundedCard,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandOrange,
          foregroundColor: const Color(0xFF220B03),
          disabledBackgroundColor: visuals.surfaceHigh,
          disabledForegroundColor: textColor.withValues(alpha: 0.38),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          iconSize: 20,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: visuals.surfaceHigh,
          foregroundColor: textColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          iconSize: 20,
          side: BorderSide(color: visuals.outlineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandOrange,
        foregroundColor: Color(0xFF220B03),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: textColor,
              backgroundColor: visuals.surfaceHigh,
              disabledForegroundColor: textColor.withValues(alpha: 0.38),
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
              iconSize: 20,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.disabled)
                      ? visuals.outline
                      : states.contains(WidgetState.focused)
                      ? accentForeground
                      : visuals.outline,
                ),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textColor,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: textTheme.labelLarge,
          iconSize: 20,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(fontSize: 14, color: visuals.textMuted),
        floatingLabelStyle: const TextStyle(fontSize: 14),
        helperStyle: TextStyle(fontSize: 12, color: visuals.textMuted),
        helperMaxLines: 6,
        errorMaxLines: 4,
        filled: true,
        fillColor: visuals.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? brandOrange : accentForeground,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: visuals.surfaceLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: visuals.accentSoft,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? textColor
                : visuals.textMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            fontSize: 12,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? accentForeground
                : visuals.textMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: visuals.surfaceLow,
        indicatorColor: visuals.accentSoft,
        selectedIconTheme: IconThemeData(color: accentForeground),
        unselectedIconTheme: IconThemeData(color: visuals.textMuted),
        selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accentForeground,
        unselectedLabelColor: visuals.textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        indicatorColor: brandOrange,
        dividerColor: visuals.outline,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: visuals.surfaceHigh,
        selectedColor: visuals.accentSoft,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: visuals.outlineStrong),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        secondaryLabelStyle: textTheme.labelLarge,
        checkmarkColor: accentForeground,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return states.contains(WidgetState.selected)
                ? visuals.accentSoft
                : visuals.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return states.contains(WidgetState.selected)
                ? accentForeground
                : visuals.textMuted;
          }),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: visuals.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: visuals.outlineStrong),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(visuals.surfaceHigh),
        headingTextStyle: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
        dividerThickness: 1,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        iconColor: accentForeground,
        collapsedIconColor: visuals.textMuted,
        textColor: textColor,
        collapsedTextColor: textColor,
      ),
      dividerTheme: DividerThemeData(
        color: visuals.outline,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brandOrange,
        linearTrackColor: progressTrack,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: visuals.surfaceHigh,
        contentTextStyle: TextStyle(color: textColor),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: dialogOutline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dialogSurface,
        modalBackgroundColor: dialogSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: accentForeground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      ),
    );
  }
}

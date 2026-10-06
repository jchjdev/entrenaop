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
      Theme.of(this).extension<EntrenaVisuals>() ?? EntrenaVisuals.dark;
}

abstract final class EntrenaTheme {
  static const brandOrange = Color(0xFFFF5A1F);
  static const brandOrangeLight = Color(0xFFFF8A50);
  static const canvas = Color(0xFF090A0D);
  static const ink = Color(0xFF17191D);
  static const textPrimary = Color(0xFFF5F3F0);

  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: brandOrange,
          brightness: Brightness.dark,
        ).copyWith(
          primary: brandOrange,
          onPrimary: const Color(0xFF220B03),
          secondary: brandOrangeLight,
          onSecondary: const Color(0xFF220B03),
          primaryContainer: EntrenaVisuals.dark.accentSoft,
          onPrimaryContainer: brandOrangeLight,
          secondaryContainer: EntrenaVisuals.dark.accentSoft,
          onSecondaryContainer: textPrimary,
          surface: EntrenaVisuals.dark.surface,
          surfaceContainerLowest: canvas,
          surfaceContainerLow: EntrenaVisuals.dark.surfaceLow,
          surfaceContainer: EntrenaVisuals.dark.surface,
          surfaceContainerHigh: EntrenaVisuals.dark.surfaceHigh,
          surfaceContainerHighest: const Color(0xFF242A32),
          onSurface: textPrimary,
          onSurfaceVariant: EntrenaVisuals.dark.textMuted,
          outline: EntrenaVisuals.dark.outlineStrong,
          outlineVariant: EntrenaVisuals.dark.outline,
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
        .apply(bodyColor: textPrimary, displayColor: textPrimary);

    const roundedCard = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      side: BorderSide(color: Color(0xFF2A2F37)),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      dividerColor: EntrenaVisuals.dark.outline,
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: Color(0xFFD8D6D2)),
      extensions: const <ThemeExtension<dynamic>>[EntrenaVisuals.dark],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF13161B),
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
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EntrenaVisuals.dark.surfaceHigh,
          foregroundColor: brandOrangeLight,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
        style: OutlinedButton.styleFrom(
          foregroundColor: brandOrangeLight,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Color(0xFF4E332A)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brandOrangeLight,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EntrenaVisuals.dark.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF343A44)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF343A44)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: brandOrange, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: EntrenaVisuals.dark.surfaceLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: EntrenaVisuals.dark.accentSoft,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? textPrimary
                : EntrenaVisuals.dark.textMuted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            fontSize: 12,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? brandOrangeLight
                : EntrenaVisuals.dark.textMuted,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF0D0F12),
        indicatorColor: Color(0xFF3A1B10),
        selectedIconTheme: IconThemeData(color: brandOrangeLight),
        unselectedIconTheme: IconThemeData(color: Color(0xFFA9A6A3)),
        selectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w800),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: brandOrangeLight,
        unselectedLabelColor: Color(0xFFA9A6A3),
        labelStyle: TextStyle(fontWeight: FontWeight.w800),
        indicatorColor: brandOrange,
        dividerColor: Color(0xFF2A2F37),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: EntrenaVisuals.dark.surfaceHigh,
        selectedColor: EntrenaVisuals.dark.accentSoft,
        surfaceTintColor: Colors.transparent,
        side: const BorderSide(color: Color(0xFF3A414C)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        secondaryLabelStyle: textTheme.labelLarge,
        checkmarkColor: brandOrangeLight,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return states.contains(WidgetState.selected)
                ? EntrenaVisuals.dark.accentSoft
                : EntrenaVisuals.dark.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return null;
            return states.contains(WidgetState.selected)
                ? brandOrangeLight
                : EntrenaVisuals.dark.textMuted;
          }),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color(0xFF1A1E24),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: Color(0xFF3A414C)),
        ),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFF1A1E24)),
        headingTextStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        dividerThickness: 1,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        iconColor: brandOrangeLight,
        collapsedIconColor: Color(0xFFA9A6A3),
        textColor: textPrimary,
        collapsedTextColor: textPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2F37),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandOrange,
        linearTrackColor: Color(0xFF2A1A14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: EntrenaVisuals.dark.surfaceHigh,
        contentTextStyle: const TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF15181D),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: Color(0xFF343A44)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF15181D),
        modalBackgroundColor: Color(0xFF15181D),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFFFF8A50),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      ),
    );
  }
}

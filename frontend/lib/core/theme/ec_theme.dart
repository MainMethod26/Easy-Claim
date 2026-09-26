import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ec_status_colors.dart';
import 'ec_tokens.dart';

/// The one EasyClaim theme (light + dark). Customer, staff, insurer-admin and superadmin
/// screens all use it; role shells differ in navigation and content, not in visual system.
///
/// [useGoogleFonts] is false in widget tests (no network); the app keeps Plus Jakarta Sans.
class EcTheme {
  EcTheme._();

  static ThemeData light({bool useGoogleFonts = true}) => _build(Brightness.light, useGoogleFonts);
  static ThemeData dark({bool useGoogleFonts = true}) => _build(Brightness.dark, useGoogleFonts);

  static ThemeData _build(Brightness brightness, bool useGoogleFonts) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: EcColors.brand,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? EcColors.brandDark : EcColors.brand,
      onPrimary: Colors.white,
      surface: isDark ? EcColors.darkSurface : EcColors.surface,
      onSurface: isDark ? EcColors.darkInk : EcColors.ink,
      onSurfaceVariant: isDark ? EcColors.darkInkMuted : EcColors.inkMuted,
      outline: isDark ? EcColors.darkLine : EcColors.line,
      outlineVariant: isDark ? EcColors.darkLine : EcColors.line,
      error: EcColors.danger,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    final text = useGoogleFonts ? GoogleFonts.plusJakartaSansTextTheme(base.textTheme) : base.textTheme;
    final textTheme = text
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1),
          titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        );
    final pageBg = isDark ? EcColors.darkBg : EcColors.surfaceAlt;
    final border = BorderSide(color: scheme.outline);

    return base.copyWith(
      scaffoldBackgroundColor: pageBg,
      textTheme: textTheme,
      extensions: [isDark ? EcStatusColors.dark : EcStatusColors.light],
      visualDensity: VisualDensity.standard,
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium,
        shape: Border(bottom: border),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: EcRadius.card, side: border),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: isDark ? EcColors.darkSurfaceAlt : EcColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.md), borderSide: border),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.md), borderSide: border),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EcRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
          padding: const EdgeInsets.symmetric(horizontal: EcSpace.lg, vertical: EcSpace.md),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
          side: border,
          padding: const EdgeInsets.symmetric(horizontal: EcSpace.lg, vertical: EcSpace.md),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(isDark ? EcColors.darkSurfaceAlt : EcColors.surfaceSunken),
        headingTextStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
        dataTextStyle: textTheme.bodyMedium,
        dividerThickness: 1,
        headingRowHeight: 40,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 52,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.pill)),
        side: BorderSide.none,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: EcColors.ink, borderRadius: BorderRadius.circular(EcRadius.sm)),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Lema's design tokens: a graphite neutral ramp, one tally-amber accent,
/// a 4px spacing grid and nested radii. Screens move onto these in Phase 3.
class LemaTheme {
  const LemaTheme._();

  // Graphite ramp.
  static const Color canvasLight = Color(0xFFF6F6F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color raisedLight = Color(0xFFEFEFED);
  static const Color inkLight = Color(0xFF1C1C1A);
  static const Color inkSecondaryLight = Color(0xFF5E5E5A);
  static const Color inkMutedLight = Color(0xFF8A8A85);

  static const Color canvasDark = Color(0xFF111110);
  static const Color surfaceDark = Color(0xFF1A1A19);
  static const Color raisedDark = Color(0xFF242423);
  static const Color inkDark = Color(0xFFEDEDEB);
  static const Color inkSecondaryDark = Color(0xFFA6A6A1);
  static const Color inkMutedDark = Color(0xFF75756F);

  /// Tally amber: the one accent. [accentInk] is the darker shade for text.
  static const Color accent = Color(0xFFD9690B);
  static const Color accentInk = Color(0xFFA84F06);

  // Semantic, toned to sit in the ramp.
  static const Color success = Color(0xFF2F8A55);
  static const Color danger = Color(0xFFC4392F);

  // 4px grid.
  static const double s1 = 4, s2 = 8, s3 = 12, s4 = 16, s5 = 20, s6 = 24, s8 = 32;

  // Nested radii.
  static const double radiusControl = 8, radiusCard = 14, radiusSheet = 20;

  static Color hairline(bool isDark) =>
      (isDark ? inkDark : inkLight).withValues(alpha: 0.08);

  static ThemeData light = _theme(Brightness.light);
  static ThemeData dark = _theme(Brightness.dark);

  static ThemeData _theme(Brightness b) {
    final isDark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: b).copyWith(
      primary: isDark ? accent : accentInk,
      onPrimary: isDark ? inkLight : Colors.white,
      surface: isDark ? surfaceDark : surfaceLight,
      onSurface: isDark ? inkDark : inkLight,
      onSurfaceVariant: isDark ? inkSecondaryDark : inkSecondaryLight,
      surfaceContainerHighest: isDark ? raisedDark : raisedLight,
      outlineVariant: hairline(isDark),
      error: danger,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? canvasDark : canvasLight,
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: hairline(isDark)),
        ),
      ),
      dividerTheme: DividerThemeData(color: hairline(isDark), thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.surfaceContainerHighest,
        elevation: 0,
        height: 64,
      ),
    );
  }
}

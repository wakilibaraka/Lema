import 'package:flutter/material.dart';

/// Backdrop design tokens — the Instagram-inspired event-feed language
/// (LEMA_DESIGN_PLAN.md §1). The Home surface uses these; other screens
/// keep [AppleTheme] until they migrate.
class BackdropTheme {
  BackdropTheme._();

  /// Story-ring magenta — the Home interactive accent.
  static const Color accent = Color(0xFFD62976);

  /// Instagram story-ring gradient (warm → magenta → violet → blue).
  static const List<Color> ringGradient = [
    Color(0xFFFEDA75),
    Color(0xFFFA7E1E),
    Color(0xFFD62976),
    Color(0xFF962FBF),
    Color(0xFF4F5BD5),
  ];

  static Color ink(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF0A0A0C);

  static Color inkSecondary(bool isDark) =>
      isDark ? Colors.white60 : const Color(0xFF6E6E76);

  static Color inkTertiary(bool isDark) =>
      isDark ? Colors.white38 : const Color(0xFFA0A0A8);

  static Color card(bool isDark) =>
      isDark ? const Color(0xFF16161B) : Colors.white;

  static Color hairline(bool isDark) =>
      isDark ? Colors.white10 : Colors.black.withAlpha(20);

  /// Frosted circular header button fill (search / bell).
  static Color glassCircle(bool isDark) =>
      isDark ? Colors.white.withAlpha(25) : Colors.white70;

  /// Backdrop event-card surface: white slab, 24pt radius, hairline, soft
  /// shadow.
  static BoxDecoration cardDecoration(bool isDark, {double radius = 24}) {
    return BoxDecoration(
      color: card(isDark),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: hairline(isDark)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(isDark ? 60 : 16),
          blurRadius: 22,
          offset: const Offset(0, 9),
        ),
      ],
    );
  }

  static BoxDecoration circleDecoration(bool isDark) {
    return BoxDecoration(
      color: glassCircle(isDark),
      shape: BoxShape.circle,
      border: Border.all(color: hairline(isDark)),
    );
  }

  // ── Shell tokens ────────────────────────────────────────────────────
  //
  // The sidebar / title bar chrome. Close to the canvas in value so the frame
  // reads as one surface with the content, separated by a hairline rather than
  // by a colour step.
  static Color chrome(bool isDark) =>
      (isDark ? const Color(0xFF141418) : const Color(0xFFF7F7FA))
          .withAlpha(isDark ? 210 : 220);

  /// The ring violet from the story-ring gradient. Used for the dark-mode
  /// theme toggle so the shell keeps a tie to the signature gradient.
  static const Color violet = Color(0xFF962FBF);

  /// Semantic status colours. The accent above is identity; these are state —
  /// never use one for the other.
  static const Color statusOnline = Color(0xFF34C759);
  static const Color statusWarning = Color(0xFFFF9500);

  /// Fill behind a selected navigation row (rail or full sidebar).
  static Color navSelected(bool isDark) =>
      accent.withAlpha(isDark ? 55 : 30);

  static Color navSelectedBorder(bool isDark) =>
      accent.withAlpha(isDark ? 100 : 70);

  static const double radiusCard = 24;
  static const double radiusControl = 12;

  /// App theme. `lib/` reads `colorScheme` nowhere, so the shell and the not
  /// yet migrated screens key off these static tokens rather than the scheme.
  static ThemeData lightTheme = _theme(Brightness.light);

  static ThemeData darkTheme = _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0E0E10) : canvasLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
      ),
      fontFamily: '.SF Pro Text',
      cardTheme: CardThemeData(
        color: card(isDark),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: hairline(isDark)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: hairline(isDark),
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// The off-white canvas the reference feed sits on.
  static const Color canvasLight = Color(0xFFF5F5F8);

  /// The ring stroke around a story avatar. [dim] renders the inactive grey
  /// ring; otherwise the signature gradient (or solid accent when selected).
  static BoxDecoration ringDecoration({bool dim = false, bool selected = false}) {
    if (dim) {
      return BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.withAlpha(70), width: 2.5),
      );
    }
    if (selected) {
      return BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 2.5),
      );
    }
    return const BoxDecoration(
      shape: BoxShape.circle,
      gradient: SweepGradient(
        colors: ringGradient,
        transform: GradientRotation(-1.2),
      ),
    );
  }
}

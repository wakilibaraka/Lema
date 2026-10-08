import 'package:flutter/material.dart';

class AppleTheme {
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemOrange = Color(0xFFFF9500);
  static const Color systemPink = Color(0xFFFF2D55);
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemIndigo = Color(0xFF5856D6);
  static const Color systemPurple = Color(0xFFAF52DE);
  static const Color systemTeal = Color(0xFF30B0C7);
  static const Color systemGray = Color(0xFF8E8E93);
  static const Color systemRed = Color(0xFFFF3B30);

  // Border radius standards
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 18.0;
  static const double radiusXl = 24.0;

  // Blur standards
  static const double blurCard = 20.0;
  static const double blurModal = 30.0;

  // Light Mode Colors
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightGlass = Color(0xCCFFFFFF); // 80% opacity
  static const Color lightBorder = Color(0x14000000); // 8% black

  // Dark Mode Colors
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkGlass = Color(0xCC1C1C1E); // 80% opacity
  static const Color darkBorder = Color(0x1FFFFFFF); // 12% white

  static Color cardBg(bool isDark) =>
      isDark ? const Color(0xFF1C1C1E).withAlpha(190) : Colors.white.withAlpha(220);

  static Color cardBorder(bool isDark) =>
      isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(18);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme.light(
      primary: systemBlue,
      secondary: systemOrange,
      surface: lightSurface,
    ),
    fontFamily: '.SF Pro Text',
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: lightBorder),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: systemBlue,
      secondary: systemOrange,
      surface: darkSurface,
    ),
    fontFamily: '.SF Pro Text',
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: darkBorder),
      ),
    ),
  );
}

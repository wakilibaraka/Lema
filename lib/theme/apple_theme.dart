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
  static const double blurCard = 24.0;
  static const double blurModal = 32.0;

  // Light Mode Colors - Soft Apple Canvas
  static const Color lightBg = Color(0xFFF5F5F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightGlass = Color(0xEEFFFFFF);
  static const Color lightBorder = Color(0x10000000); // 6% black

  // Dark Mode Colors - Deep Titanium
  static const Color darkBg = Color(0xFF0C0C0F);
  static const Color darkSurface = Color(0xFF18181D);
  static const Color darkGlass = Color(0xDD18181D);
  static const Color darkBorder = Color(0x18FFFFFF); // 9% white

  static Color cardBg(bool isDark) =>
      isDark ? const Color(0xFF16161B).withAlpha(220) : Colors.white.withAlpha(235);

  static Color cardBorder(bool isDark) =>
      isDark ? Colors.white.withAlpha(22) : Colors.black.withAlpha(14);

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
    dividerTheme: const DividerThemeData(
      color: lightBorder,
      thickness: 1,
      space: 1,
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
    dividerTheme: const DividerThemeData(
      color: darkBorder,
      thickness: 1,
      space: 1,
    ),
  );
}

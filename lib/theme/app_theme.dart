import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand colours ─────────────────────────────────────────
  static const Color black      = Color(0xFF111111);
  static const Color white      = Color(0xFFFFFFFF);
  static const Color grey100    = Color(0xFFF9F9F8);
  static const Color grey200    = Color(0xFFF3F4F6);
  static const Color grey300    = Color(0xFFE5E7E6);
  static const Color grey500    = Color(0xFF9CA3AF);
  static const Color grey700    = Color(0xFF6B7280);
  static const Color accentBlue = Color(0xFF2563EB);

  // Category colour palette
  static const Color catAcademic = Color(0xFF6366F1); // indigo
  static const Color catTravel   = Color(0xFF0EA5E9); // sky blue
  static const Color catPersonal = Color(0xFFEC4899); // pink
  static const Color catWork     = Color(0xFFF59E0B); // amber
  static const Color catOther    = Color(0xFF10B981); // emerald

  // ── Dark mode ──────────────────────────────────────────────
  static const Color darkBg      = Color(0xFF111111);
  static const Color darkSurface = Color(0xFF1C1C1C);
  static const Color darkBorder  = Color(0xFF2A2A2A);
  static const Color darkText    = Color(0xFFF5F5F5);
  static const Color darkMuted   = Color(0xFF9CA3AF);

  // ── Helper: category colour ────────────────────────────────
  static Color categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'academic': return catAcademic;
      case 'travel':   return catTravel;
      case 'personal': return catPersonal;
      case 'work':     return catWork;
      default:         return catOther;
    }
  }

  // ── Light theme ───────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: white,
    fontFamily: 'SF Pro Display',

    colorScheme: const ColorScheme.light(
      primary: black,
      secondary: grey700,
      surface: white,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: white,
      foregroundColor: black,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: black,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: grey200,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: grey300, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: grey300, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: black, width: 1),
      ),
      labelStyle: const TextStyle(color: grey500, fontSize: 12),
      hintStyle: const TextStyle(color: grey500, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: black,
        foregroundColor: white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    cardTheme: CardThemeData(
      color: grey100,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: grey300, width: 0.5),
      ),
    ),
  );

  // ── Dark theme ────────────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBg,

    colorScheme: const ColorScheme.dark(
      primary: white,
      secondary: darkMuted,
      surface: darkSurface,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: darkBg,
      foregroundColor: darkText,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: darkText,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: darkBorder, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: darkBorder, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: darkText, width: 1),
      ),
      labelStyle: const TextStyle(color: darkMuted, fontSize: 12),
      hintStyle: const TextStyle(color: darkMuted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: white,
        foregroundColor: black,
        elevation: 0,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: darkBorder, width: 0.5),
      ),
    ),
  );
}

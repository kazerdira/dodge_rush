import 'package:flutter/material.dart';

class AppTheme {
  // Deep space palette
  static const Color bg = Color(0xFF03040E);
  static const Color bgDeep = Color(0xFF01020A);
  static const Color card = Color(0xFF0A0B1A);
  static const Color cardBorder = Color(0xFF161830);

  // Neon accents
  static const Color accent = Color(0xFF00FFD1);
  static const Color accentAlt = Color(0xFF4D7CFF);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color orange = Color(0xFFFF6B2B);

  // Status colors
  static const Color danger = Color(0xFFFF2D55);
  static const Color warning = Color(0xFFFFB020);
  static const Color coinColor = Color(0xFFFFD60A);
  static const Color shieldColor = Color(0xFF4D7CFF);
  static const Color slowColor = Color(0xFF8B5CF6);

  // Text
  static const Color textPrimary = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF5A6490);
  static const Color textDim = Color(0xFF2A2F50);

  // Font family — Space Grotesk (fallback: system sans)
  // To fully activate: add google_fonts package + SpaceGrotesk font files in assets
  static const String fontFamily = 'SpaceMono';

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accentAlt,
      surface: card,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
    // Using Courier as the monospace sci-fi font — matches the space theme
    fontFamily: 'Courier',
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.w900, letterSpacing: 2, color: textPrimary),
      displayMedium: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.w900, letterSpacing: 1.5, color: textPrimary),
      headlineLarge: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.w900, letterSpacing: 3, color: textPrimary),
      headlineMedium: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.w800, letterSpacing: 2, color: textPrimary),
      bodyLarge: TextStyle(fontFamily: 'Courier', color: textSecondary, height: 1.5),
      bodyMedium: TextStyle(fontFamily: 'Courier', color: textSecondary, height: 1.5),
      labelSmall: TextStyle(fontFamily: 'Courier', color: textDim, letterSpacing: 2, fontWeight: FontWeight.w700),
    ),
  );
}

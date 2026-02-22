import 'package:flutter/material.dart';

class AppTheme {
  // Deep space palette
  static const Color bg = Color(0xFF03040E);
  static const Color bgDeep = Color(0xFF01020A);
  static const Color card = Color(0xFF0A0B1A);
  static const Color cardBorder = Color(0xFF161830);
  
  // Neon accents
  static const Color accent = Color(0xFF00FFD1);       // Cyan-green thrust
  static const Color accentAlt = Color(0xFF4D7CFF);    // Deep blue energy
  static const Color purple = Color(0xFF8B5CF6);       // Purple nebula
  static const Color orange = Color(0xFFFF6B2B);       // Asteroid orange
  
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

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accentAlt,
      surface: card,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
    fontFamily: 'Courier',
  );
}

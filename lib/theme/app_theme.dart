import 'package:flutter/material.dart';

class AppTheme {
  static const Color bg = Color(0xFF07070F);
  static const Color card = Color(0xFF111120);
  static const Color cardBorder = Color(0xFF1C1C30);
  static const Color accent = Color(0xFF00F5A0);
  static const Color accentAlt = Color(0xFF00B4FF);
  static const Color danger = Color(0xFFFF3B5C);
  static const Color warning = Color(0xFFFF8C42);
  static const Color coinColor = Color(0xFFFFB800);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF7878A0);
  static const Color slowColor = Color(0xFFBF00FF);
  static const Color shieldColor = Color(0xFF00B4FF);

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
            primary: accent, secondary: accentAlt, surface: card),
        appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent, elevation: 0),
      );
}

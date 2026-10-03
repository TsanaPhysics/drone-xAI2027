import 'package:flutter/material.dart';

class AppTheme {
  static const Color darkBg = Color(0xFF070A12);
  static const Color cardBg = Color(0xFF0E1525);
  static const Color neonCyan = Color(0xFF00F0FF);
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonRed = Color(0xFFFF3366);
  static const Color neonYellow = Color(0xFFFFB703);
  static const Color textDim = Color(0xFF7F91B3);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: neonCyan,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonGreen,
        error: neonRed,
        surface: cardBg,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A0F1C),
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}

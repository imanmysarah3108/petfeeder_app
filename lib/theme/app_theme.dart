import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color backgroundColor = Color(0xFFF9F6F2);
  static const Color primaryColor = Color(0xFFD66B1E);
  static const Color darkPrimary = Color(0xFF8D4610);
  static const Color textDark = Color(0xFF333333);
  static const Color cardColor = Colors.white;
  static const Color onlineBg = Color(0xFFE8F5E9);
  static const Color onlineColor = Color(0xFF4CAF50);
  static const Color surfaceColor = Color(0xFFF4ECE5);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        background: backgroundColor,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        foregroundColor: darkPrimary,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
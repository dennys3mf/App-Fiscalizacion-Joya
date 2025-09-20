import 'package:flutter/material.dart';


class AppTheme {
  // --- COLORES PRINCIPALES ---
  static const Color primaryRed = Color(0xFFDA291C);
  static const Color primaryBlue = Color(0xFF005A9C);
  static const Color background = Color(0xFFF0F4F8);
  static const Color foregroundDark = Color(0xFF1C1C1E);
  static const Color mutedForeground = Color(0xFF6B7280);

  // --- GRADIENTES ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryRed, Color(0xFFB92317)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, Color(0xFFE5E9EC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // --- TEMA GENERAL DE LA APP ---
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryRed,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primaryRed,
        secondary: primaryBlue,
        surface: Colors.white,
        background: background,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: foregroundDark,
        onBackground: foregroundDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: foregroundDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: foregroundDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.0),
          borderSide: const BorderSide(color: primaryRed, width: 2.0),
        ),
        labelStyle: const TextStyle(color: mutedForeground),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
          elevation: 4,
          shadowColor: primaryRed.withOpacity(0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
           foregroundColor: primaryRed,
           side: const BorderSide(color: primaryRed, width: 1.5),
           padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
             shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
        )
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: foregroundDark),
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: foregroundDark),
      ),
    );
  }
}
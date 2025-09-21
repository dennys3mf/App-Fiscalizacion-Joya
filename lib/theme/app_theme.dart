import 'package:flutter/material.dart';

class AppTheme {
  // La Joya Avanza Color Palette
  static const Color primaryRed = Color(0xFFDC143C);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color foregroundDark = Color(0xFF1A1D29);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color secondaryGray = Color(0xFF6B7280);
  static const Color mutedGray = Color(0xFFF1F5F9);
  static const Color mutedForeground = Color(0xFF64748B);
  static const Color accentRed = Color(0xFFE11D48);
  static const Color borderColor = Color(0x14DC143C);

  // Compatibilidad con código existente
  static const Color background = backgroundLight;
  static const Color primaryBlue = Color(0xFF005A9C);
  static const Color card = cardWhite;
  static const Color accent = accentRed;
  static const Color border = borderColor;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryRed,
      brightness: Brightness.light,
      primary: primaryRed,
      onPrimary: Colors.white,
      secondary: secondaryGray,
      onSecondary: Colors.white,
      surface: cardWhite,
      onSurface: foregroundDark,
      background: backgroundLight,
      onBackground: foregroundDark,
    ),
    scaffoldBackgroundColor: backgroundLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: foregroundDark,
      titleTextStyle: TextStyle(
        color: foregroundDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
    ),
    cardTheme: CardThemeData(
      color: cardWhite,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: primaryRed.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryRed,
        side: const BorderSide(color: primaryRed, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: mutedGray.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primaryRed, width: 2),
      ),
      labelStyle: const TextStyle(
        color: mutedForeground,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(
        color: mutedForeground,
        fontFamily: 'Inter',
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: foregroundDark,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      ),
      displayMedium: TextStyle(
        color: foregroundDark,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        fontFamily: 'Inter',
      ),
      displaySmall: TextStyle(
        color: foregroundDark,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
      headlineLarge: TextStyle(
        color: foregroundDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
      headlineMedium: TextStyle(
        color: foregroundDark,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
      bodyLarge: TextStyle(
        color: foregroundDark,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        fontFamily: 'Inter',
      ),
      bodyMedium: TextStyle(
        color: foregroundDark,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        fontFamily: 'Inter',
      ),
      bodySmall: TextStyle(
        color: mutedForeground,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        fontFamily: 'Inter',
      ),
    ),
    fontFamily: 'Inter',
  );

  static ThemeData darkTheme = lightTheme.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryRed,
      brightness: Brightness.dark,
    ),
  );

  // Compatibilidad con código existente
  static ThemeData get theme => lightTheme;

  // Gradientes personalizados
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF8ECDF7), // Celeste suave
      Color(0xFFDC143C), // Rojo principal
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [
      Color(0xFFF8F9FA), // Fondo claro
      Color(0xFFFFE2E2), // Rosa muy suave
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [
      Color(0xFFFFFFFF), // Blanco
      Color(0xFFF8F9FA), // Fondo muy claro
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

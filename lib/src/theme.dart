import 'package:flutter/material.dart';

class KasudloColors {
  static const primary = Color(0xFF2A84E6);
  static const primaryDark = Color(0xFF0A2D6B);
  static const secondary = Color(0xFF38BDF8);
  static const warning = Color(0xFFD97706);
  static const critical = Color(0xFFE11D48);
  static const surface = Color(0xFFF8F9FA);
  static const surfaceContainer = Color(0xFFFFFFFF);
  static const border = Color(0xFFBDC9C6);
  static const text = Color(0xFF191C1D);
  static const muted = Color(0xFF3E4947);
}

ThemeData buildKasudloTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: KasudloColors.primary,
    brightness: Brightness.light,
    primary: KasudloColors.primary,
    secondary: KasudloColors.secondary,
    error: KasudloColors.critical,
    surface: KasudloColors.surface,
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: KasudloColors.border),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: KasudloColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: KasudloColors.surface,
      foregroundColor: KasudloColors.text,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: KasudloColors.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: KasudloColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: KasudloColors.primary, width: 1.5),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: KasudloColors.critical),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      floatingLabelStyle: const TextStyle(
        color: KasudloColors.muted,
        fontWeight: FontWeight.w700,
        backgroundColor: Colors.white,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: KasudloColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: KasudloColors.primary,
        side: const BorderSide(color: KasudloColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: KasudloColors.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? KasudloColors.primary
              : KasudloColors.muted,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        height: 1.26,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        height: 1.33,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(fontSize: 18, height: 1.45, letterSpacing: 0),
      bodyMedium: TextStyle(fontSize: 16, height: 1.5, letterSpacing: 0),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.42,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(fontSize: 12, height: 1.33, letterSpacing: 0),
    ).apply(bodyColor: KasudloColors.text, displayColor: KasudloColors.text),
  );
}

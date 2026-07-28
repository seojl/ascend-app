import 'package:flutter/material.dart';

class AppColors {
  static const void_ = Color(0xFF05070D);
  static const panel = Color(0xFF0C121D);
  static const panel2 = Color(0xFF111A29);
  static const border = Color(0xFF243248);
  static const cyan = Color(0xFF4CE0FF);
  static const violet = Color(0xFFA78BFA);
  static const danger = Color(0xFFFF5470);
  static const text = Color(0xFFE8EDF5);
  static const muted = Color(0xFF7C8AA3);
}

ThemeData buildAscendTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.void_,
    primaryColor: AppColors.cyan,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cyan,
      secondary: AppColors.violet,
      surface: AppColors.panel,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.void_,
      elevation: 0,
      foregroundColor: AppColors.text,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      bodyMedium: TextStyle(color: AppColors.text),
      bodySmall: TextStyle(color: AppColors.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel2,
      border: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.cyan)),
      labelStyle: const TextStyle(color: AppColors.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.void_,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.panel,
      selectedItemColor: AppColors.cyan,
      unselectedItemColor: AppColors.muted,
    ),
    cardColor: AppColors.panel,
    dividerColor: AppColors.border,
  );
}

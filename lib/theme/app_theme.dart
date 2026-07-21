import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF00AEEF);
  static const secondary = Color(0xFF262262);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      secondary: AppColors.secondary,
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      secondary: AppColors.secondary,
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.brightness == Brightness.light
          ? const Color(0xFFF5F5FA)
          : const Color(0xFF121218),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF1B1B24),
        foregroundColor: scheme.brightness == Brightness.light
            ? AppColors.secondary
            : Colors.white,
        elevation: 0.5,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF1B1B24),
        selectedItemColor: AppColors.primary,
        unselectedItemColor:
            scheme.brightness == Brightness.light ? const Color(0xFF9A9AB2) : const Color(0xFF6E6E82),
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF1E1E27),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF1E1E27),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

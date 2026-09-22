import 'package:flutter/material.dart';

/// Central place for colors pulled from the mockup. These are close
/// approximations - open the Figma file's Inspect panel on any layer
/// and copy the exact hex values in if you want a pixel-perfect match.
class AppColors {
  static const primary = Color(0xFF2B1B4E); // deep purple header / nav pill
  static const accent = Color(0xFFE0245E); // pink highlight (urgent items, FAB)
  static const background = Color(0xFFF5F5F7);
  static const cardBackground = Color(0xFFEFEFF2);
  static const textDark = Color(0xFF1C1C1E);
  static const textMuted = Color(0xFF8E8E93);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
    );
  }
}

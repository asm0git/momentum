// lib/theme.dart
import 'package:flutter/material.dart';

class AppSpacing {
  static const double base = 8;

  static const double xs = base * 0.5; // 4
  static const double sm = base; // 8
  static const double md = base * 2; // 16
  static const double lg = base * 3; // 24

  static const double screenEdgePadding = md; // 16 pt
  static const double listItemGap = sm; // 8 pt
  static const double sectionGap = lg; // 24 pt
}

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: const Color(0xFF342066),
    onPrimary: const Color(0xFFFFFFFF),
    secondary: const Color(0xFFC62E65),
    surface: const Color(0xFFF4F4F4),
    onSurface: const Color(0xFF1E293B),
    error: const Color(0xFF961212),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontFamily: 'SFProRounded',
      fontSize: 36,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      fontFamily: 'SFProRounded',
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'SFProRounded',
      fontSize: 16,
      fontWeight: FontWeight.normal,
    ),
    bodySmall: TextStyle(
      fontFamily: 'SFProRounded',
      fontSize: 12,
      fontWeight: FontWeight.normal,
    ),
    labelSmall: TextStyle(
      fontFamily: 'SFProRounded',
      fontSize: 8,
      fontWeight: FontWeight.normal,
    ),
  ),
  cardTheme: const CardThemeData(
    margin: EdgeInsets.all(AppSpacing.sm),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
  ),
);

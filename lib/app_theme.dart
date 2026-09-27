import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const primary = Color(0xFF342066);
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFC62E65);
  static const surface = Color(0xFFF4F4F4);
  static const onSurface = Color(0xFF1E293B);
  static const error = Color(0xFF961212);
  static const transparent = Colors.transparent;
  static const popupScrim = Color(0x26000000);
  static const disabled = Color(0xFF94A3B8);
}

class AppSpacing {
  static const double base = 8;

  static const double xs = base;
  static const double sm = base;
  static const double md = base * 2;
  static const double lg = base * 3;

  static const double navigationInset = 0.5;

  static const double screenEdgePadding = md;
  static const double listItemGap = sm;
  static const double sectionGap = lg;
  static const double appBarHeight = base * 13;
  static const double navigationDockHeight = base * 9;
  static const double navigationIconSize = base * 3;
  static const double selectedIconContainerSize = base * 6;
  static const double addIconSize = base * 3;
  static const fabAnimationDuration = Duration(milliseconds: 240);
  static const double floatingGroupEdge = md;
  static const double floatingGroupBottom = md;
  static const double floatingGroupGap = sm;
  static const double popupHeight = base * 20;
}

class AppRadii {
  static const double appBarBottom = AppSpacing.base * 10;
  static const double navigationDock = AppSpacing.base * 5;
  static const double navigationItem = AppSpacing.base * 1000;
  static const double popup = AppSpacing.base * 4;
}

final appTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'SFProText',
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    error: AppColors.error,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontFamily: 'SFProDisplay',
      fontSize: 32,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      fontFamily: 'SFProDisplay',
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'SFProText',
      fontSize: 16,
      fontWeight: FontWeight.normal,
    ),
    bodySmall: TextStyle(
      fontFamily: 'SFProText',
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

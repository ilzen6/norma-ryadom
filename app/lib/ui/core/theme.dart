import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brand = Color(0xFF1F6F4A);
  static const good = Color(0xFF1E7340);
  static const compromise = Color(0xFF8A5300);
  static const none = Color(0xFF5B6168);
  static const noData = Color(0xFF9AA0A6);
  static const danger = Color(0xFFA3262A);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Roboto',
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
  );
}

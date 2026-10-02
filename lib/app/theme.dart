import 'package:flutter/material.dart';

/// Warm, calm, social. Not LinkedIn, not a dating app, not a feed.
class AppColors {
  static const terracotta = Color(0xFFE07A5F);
  static const sage = Color(0xFF81B29A);
  static const sageDark = Color(0xFF3F7D63);
  static const sand = Color(0xFFF2CC8F);
  static const cream = Color(0xFFFBF7F2);
  static const ink = Color(0xFF3D405B);
  static const inkSoft = Color(0xFF6B6E85);
  static const card = Colors.white;
  static const danger = Color(0xFFC2453B);

  // Driver mode: high contrast, dark background.
  static const driverBg = Color(0xFF1E2030);
  static const driverCard = Color(0xFF2B2E44);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.terracotta,
    primary: AppColors.terracotta,
    secondary: AppColors.sage,
    surface: AppColors.cream,
    onSurface: AppColors.ink,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Rubik',
    scaffoldBackgroundColor: AppColors.cream,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: const TextStyle(
          fontFamily: 'Rubik',
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        foregroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: const TextStyle(fontFamily: 'Rubik', fontSize: 16),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFF8DDD3),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

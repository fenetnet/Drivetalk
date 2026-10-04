import 'package:flutter/material.dart';

/// Warm, calm, social. Not LinkedIn, not a dating app, not a feed.
class AppColors {
  // Warm coral + deep green on a soft cream ground (owner-approved redesign,
  // 2026-10-04).
  static const terracotta = Color(0xFFD9573B); // coral — main action
  static const coralDeep = Color(0xFFB8462C); // coral text on white
  static const blush = Color(0xFFFFE2D2);
  static const blushDeep = Color(0xFFFFCDB5);
  static const sage = Color(0xFF3FA37A); // "free now" green
  static const sageDark = Color(0xFF2F6B57);
  static const mint = Color(0xFFE3F1EA);
  static const sand = Color(0xFFF2C58F);
  static const cream = Color(0xFFFFF6EE);
  static const ink = Color(0xFF2B2A3A);
  static const inkSoft = Color(0xFF6B6878);
  static const card = Colors.white;
  static const danger = Color(0xFFC2453B);

  // Driver mode: high contrast, dark background.
  static const driverBg = Color(0xFF171A26);
  static const driverCard = Color(0xFF2B3044);
  static const driverRing = Color(0xFF23283A);
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
      shadowColor: const Color(0x1FB8462C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFF1E6DD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFF1E6DD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.terracotta, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentTextStyle: const TextStyle(fontFamily: 'Rubik', fontSize: 15),
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
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      indicatorColor: AppColors.blush,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.coralDeep
              : AppColors.inkSoft,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'Rubik',
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w400,
          color: s.contains(WidgetState.selected)
              ? AppColors.coralDeep
              : AppColors.inkSoft,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

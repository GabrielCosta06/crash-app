import 'package:flutter/material.dart';

class AppPalette {
  // Dark theme colors
  static const Color midnight = Color(0xFF0B1120);
  static const Color deepSpace = Color(0xFF111B2E);
  static const Color aurora = Color(0xFF4F8DFF);
  static const Color neonPulse = Color(0xFF3BF4FB);
  static const Color softSlate = Color(0xFF9FAED1);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFFFC107);
  static const Color danger = Color(0xFFE74C3C);
  
  // Light theme colors
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF2563EB);
  static const Color lightSecondary = Color(0xFF0EA5E9);
  static const Color lightText = Color(0xFF1F2937);
  static const Color lightTextSecondary = Color(0xFF6B7280);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppPalette.aurora,
          secondary: AppPalette.neonPulse,
          surface: AppPalette.deepSpace,
          surfaceTint: Colors.transparent,
          tertiary: AppPalette.softSlate,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
            TargetPlatform.linux: ZoomPageTransitionsBuilder(),
            TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
            TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          },
        ),
        scaffoldBackgroundColor: AppPalette.midnight,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          color: AppPalette.deepSpace,
          elevation: 0,
          margin: EdgeInsets.all(0),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppPalette.deepSpace,
          selectedItemColor: AppPalette.neonPulse,
          unselectedItemColor: AppPalette.softSlate,
          showUnselectedLabels: true,
          showSelectedLabels: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.aurora,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppPalette.deepSpace.withValues(alpha: 0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppPalette.neonPulse, width: 1.4),
          ),
          labelStyle: const TextStyle(color: AppPalette.softSlate),
          hintStyle: const TextStyle(color: AppPalette.softSlate),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppPalette.deepSpace,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppPalette.lightPrimary,
          secondary: AppPalette.lightSecondary,
          surface: AppPalette.lightSurface,
          surfaceTint: Colors.transparent,
          tertiary: AppPalette.lightTextSecondary,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
            TargetPlatform.linux: ZoomPageTransitionsBuilder(),
            TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
            TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          },
        ),
        scaffoldBackgroundColor: AppPalette.lightBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: AppPalette.lightText,
        ),
        cardTheme: const CardThemeData(
          color: AppPalette.lightSurface,
          elevation: 2,
          margin: EdgeInsets.all(0),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppPalette.lightSurface,
          selectedItemColor: AppPalette.lightPrimary,
          unselectedItemColor: AppPalette.lightTextSecondary,
          showUnselectedLabels: true,
          showSelectedLabels: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.lightPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppPalette.lightSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.grey, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppPalette.lightPrimary, width: 1.4),
          ),
          labelStyle: const TextStyle(color: AppPalette.lightTextSecondary),
          hintStyle: const TextStyle(color: AppPalette.lightTextSecondary),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppPalette.lightText,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      );
}

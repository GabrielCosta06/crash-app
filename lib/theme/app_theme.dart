import 'package:flutter/material.dart';

/// Centralised color system ensuring a cohesive minimalist aesthetic.
class AppPalette {
  static const Color midnight = Color(0xFF0B1120);
  static const Color deepSpace = Color(0xFF12192B);
  static const Color aurora = Color(0xFF4F8DFF);
  static const Color neonPulse = Color(0xFF3BF4FB);
  static const Color softSlate = Color(0xFF9FAED1);
  static const Color softWhite = Color(0xFFF7F9FC);
  static const Color graphite = Color(0xFF1F2937);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFFFC107);
  static const Color danger = Color(0xFFE74C3C);

  // Legacy aliases kept for backwards compatibility inside existing widgets.
  static const Color lightPrimary = aurora;
  static const Color lightSecondary = neonPulse;
  static const Color lightSurface = Colors.white;
  static const Color lightBackground = softWhite;
  static const Color lightText = graphite;
  static const Color lightTextSecondary = softSlate;
}

/// Builds light and dark themes used across the application.
class AppTheme {
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.aurora,
      brightness: Brightness.dark,
      secondary: AppPalette.neonPulse,
      tertiary: AppPalette.softSlate,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      primaryColor: AppPalette.aurora,
      scaffoldBackgroundColor: AppPalette.midnight,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.deepSpace,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppPalette.softSlate,
        textColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppPalette.deepSpace,
        selectedItemColor: AppPalette.neonPulse,
        unselectedItemColor: AppPalette.softSlate,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.aurora,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.deepSpace.withValues(alpha: 0.82),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppPalette.neonPulse, width: 1.3),
        ),
        labelStyle: const TextStyle(color: AppPalette.softSlate),
        hintStyle: const TextStyle(color: AppPalette.softSlate),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppPalette.deepSpace,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      textTheme: _textTheme(
        onSurface: colorScheme.onSurface,
        isDark: true,
      ),
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.aurora,
      brightness: Brightness.light,
      secondary: AppPalette.neonPulse,
      tertiary: AppPalette.softSlate,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.softWhite,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      pageTransitionsTheme: _pageTransitions,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppPalette.graphite,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        margin: EdgeInsets.zero,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppPalette.aurora,
        textColor: AppPalette.graphite,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: AppPalette.softSlate,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppPalette.softSlate.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
        labelStyle: const TextStyle(color: AppPalette.softSlate),
        hintStyle: const TextStyle(color: AppPalette.softSlate),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppPalette.graphite,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      textTheme: _textTheme(
        onSurface: AppPalette.graphite,
        isDark: false,
      ),
    );
  }

  static PageTransitionsTheme get _pageTransitions => const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      );

  /// Builds text styles that respect the active brightness and palette.
  static TextTheme _textTheme({
    required Color onSurface,
    required bool isDark,
  }) {
    final base =
        ThemeData(brightness: isDark ? Brightness.dark : Brightness.light)
            .textTheme;
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        height: 1.5,
        color: onSurface.withValues(alpha: 0.82),
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: onSurface.withValues(alpha: 0.68),
      ),
    );
  }
}

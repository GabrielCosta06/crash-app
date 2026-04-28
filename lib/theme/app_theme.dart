import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  const AppPalette._();

  static const Color ink = Color(0xFF05070C);
  static const Color midnight = Color(0xFF090E1A);
  static const Color panel = Color(0xFF101827);
  static const Color panelElevated = Color(0xFF162033);
  static const Color border = Color(0xFF263247);
  static const Color borderStrong = Color(0xFF34445F);
  static const Color blue = Color(0xFF3E8BFF);
  static const Color blueSoft = Color(0xFF86B7FF);
  static const Color cyan = Color(0xFF65E4FF);
  static const Color text = Color(0xFFF7FAFC);
  static const Color textMuted = Color(0xFF9AA8BD);
  static const Color textSubtle = Color(0xFF69778C);
  static const Color success = Color(0xFF3DDC97);
  static const Color warning = Color(0xFFFFC857);
  static const Color danger = Color(0xFFFF6B6B);

  // Legacy aliases kept for existing widgets while the app is dark-only.
  static const Color deepSpace = panel;
  static const Color aurora = blue;
  static const Color neonPulse = cyan;
  static const Color softSlate = textMuted;
  static const Color softWhite = text;
  static const Color graphite = panelElevated;
  static const Color lightPrimary = blue;
  static const Color lightSecondary = cyan;
  static const Color lightSurface = panel;
  static const Color lightBackground = midnight;
  static const Color lightText = text;
  static const Color lightTextSecondary = textMuted;
}

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double section = 40;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
}

class AppBreakpoints {
  const AppBreakpoints._();

  static const double tablet = 720;
  static const double desktop = 1040;
  static const double wide = 1280;
}

class AppGradients {
  const AppGradients._();

  static const LinearGradient hero = LinearGradient(
    colors: <Color>[
      AppPalette.panelElevated,
      AppPalette.midnight,
      AppPalette.ink,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient accent = LinearGradient(
    colors: <Color>[
      AppPalette.blue.withValues(alpha: 0.95),
      AppPalette.cyan.withValues(alpha: 0.88),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.blue,
      brightness: Brightness.dark,
      surface: AppPalette.panel,
      secondary: AppPalette.cyan,
    );
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
    );

    final textTheme = GoogleFonts.interTextTheme(
      baseTheme.textTheme,
    ).apply(bodyColor: AppPalette.text, displayColor: AppPalette.text);

    return baseTheme.copyWith(
      scaffoldBackgroundColor: AppPalette.midnight,
      primaryColor: AppPalette.blue,
      textTheme: textTheme.copyWith(
        displaySmall: textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.05,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.1,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          height: 1.5,
          color: AppPalette.text.withValues(alpha: 0.9),
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: AppPalette.text.withValues(alpha: 0.84),
          fontWeight: FontWeight.w400,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          height: 1.45,
          color: AppPalette.textMuted,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppPalette.text, size: 22),
        actionsIconTheme: IconThemeData(color: AppPalette.text, size: 22),
        titleTextStyle: TextStyle(
          color: AppPalette.text,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppPalette.panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppPalette.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppPalette.border.withValues(alpha: 0.7),
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppPalette.borderStrong;
            }
            return AppPalette.blue;
          }),
          foregroundColor: WidgetStateProperty.all(AppPalette.text),
          elevation: WidgetStateProperty.all(0),
          overlayColor: WidgetStateProperty.all(
            AppPalette.text.withValues(alpha: 0.08),
          ),
          minimumSize: WidgetStateProperty.all(const Size(48, 52)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppPalette.blue,
          minimumSize: const Size(48, 52),
          side: const BorderSide(color: AppPalette.blue, width: 1.5),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.blueSoft,
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.panel,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppPalette.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppPalette.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppPalette.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppPalette.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppPalette.danger, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppPalette.textMuted),
        floatingLabelStyle: const TextStyle(color: AppPalette.blueSoft),
        errorStyle: const TextStyle(color: AppPalette.danger, fontSize: 12),
        hintStyle: const TextStyle(color: AppPalette.textSubtle),
        prefixIconColor: AppPalette.textMuted,
        suffixIconColor: AppPalette.textSubtle,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.panel,
        selectedColor: AppPalette.blue,
        disabledColor: AppPalette.panel,
        labelStyle: const TextStyle(color: AppPalette.textMuted),
        secondaryLabelStyle: const TextStyle(color: AppPalette.text),
        side: const BorderSide(color: AppPalette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppPalette.panel,
        selectedItemColor: AppPalette.blue,
        unselectedItemColor: AppPalette.textSubtle,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.panel,
        indicatorColor: AppPalette.blue.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppPalette.blue
                : AppPalette.textSubtle,
            size: 22,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppPalette.blue
                : AppPalette.textSubtle,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppPalette.midnight,
        selectedIconTheme: const IconThemeData(color: AppPalette.blue),
        unselectedIconTheme: const IconThemeData(color: AppPalette.textSubtle),
        selectedLabelTextStyle: const TextStyle(
          color: AppPalette.blue,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelTextStyle: const TextStyle(color: AppPalette.textSubtle),
        indicatorColor: AppPalette.blue.withValues(alpha: 0.18),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppPalette.border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.panelElevated,
        contentTextStyle: const TextStyle(color: AppPalette.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
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
    );
  }

  /// Compatibility getter. Crash App intentionally ships dark-mode only.
  static ThemeData get light => dark;
}

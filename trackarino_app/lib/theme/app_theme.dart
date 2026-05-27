import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        isDark
            ? const ColorScheme.dark(
              primary: AppColors.deepGreenLight,
              onPrimary: Colors.white,
              secondary: AppColors.statusPending,
              surface: AppColors.darkSurface,
              onSurface: Color(0xFFE5E7EB),
              error: AppColors.alertCritical,
            )
            : ColorScheme.fromSeed(
              seedColor: AppColors.deepGreen,
              primary: AppColors.deepGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.graphite900,
              error: AppColors.alertCritical,
              brightness: Brightness.light,
            );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.inkBlack : AppColors.graphite50,
      cardTheme: CardThemeData(
        elevation: isDark ? 2 : 1,
        color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: isDark ? AppColors.darkSurfaceHigh : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.graphite900,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: AppColors.graphite700,
        showUnselectedLabels: true,
        elevation: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSpacing.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark
                ? Colors.white.withValues(alpha: 0.055)
                : AppColors.graphite50,
        labelStyle: TextStyle(
          color: isDark ? AppColors.graphite300 : AppColors.graphite700,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.graphite700 : AppColors.graphite700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color:
                isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.graphite200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color:
                isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.graphite200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.emerald400, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.alertCritical),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.graphite700 : AppColors.graphite200,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        ),
      ),
    );

    return base.copyWith(textTheme: _textTheme(base.textTheme, isDark));
  }

  static TextTheme _textTheme(TextTheme base, bool isDark) {
    final color = isDark ? const Color(0xFFE5E7EB) : AppColors.graphite900;
    final muted = isDark ? AppColors.graphite200 : AppColors.graphite700;

    return base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: color),
      bodyMedium: base.bodyMedium?.copyWith(color: color),
      bodySmall: base.bodySmall?.copyWith(color: muted, fontSize: 13),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

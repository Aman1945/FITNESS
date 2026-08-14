import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Spacing scale. Every gap in the app comes from here rather than magic numbers.
class Gap {
  const Gap._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const page = 20.0;
  static const radius = 18.0;
  static const radiusSm = 12.0;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkDark : AppColors.ink;
    final muted = isDark ? AppColors.mutedDark : AppColors.muted;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final canvas = isDark ? AppColors.canvasDark : AppColors.canvas;
    final border = isDark ? AppColors.borderDark : AppColors.border;
    final primary = isDark ? AppColors.primaryDark : AppColors.primary;

    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
      ).copyWith(primary: primary, surface: surface),
      textTheme: _textTheme(ink, muted),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: ink),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Gap.radius),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF20202E) : const Color(0xFFF4F4F8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.lg),
        hintStyle: TextStyle(color: muted, fontSize: 15),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(primary),
        errorBorder: _inputBorder(AppColors.behind),
        focusedErrorBorder: _inputBorder(AppColors.behind),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Gap.radiusSm + 2),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Gap.radiusSm + 2),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF23232F) : const Color(0xFFF1F1F6),
        side: BorderSide.none,
        labelStyle: TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: canvas, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gap.radiusSm)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
        linearMinHeight: 8,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Gap.radiusSm + 2),
        borderSide: BorderSide(color: color, width: 1.4),
      );

  static TextTheme _textTheme(Color ink, Color muted) => TextTheme(
        displaySmall: TextStyle(
            fontSize: 30, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.8),
        headlineMedium: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.6),
        headlineSmall: TextStyle(
            fontSize: 21, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.4),
        titleLarge: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.2),
        titleMedium: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: ink),
        bodyLarge: TextStyle(fontSize: 15.5, color: ink, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, color: muted, height: 1.45),
        bodySmall: TextStyle(fontSize: 12.5, color: muted, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
      );
}

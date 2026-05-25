// lib/services/theme.dart

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Telegram-like dark palette
  static const Color background = Color(0xFF0E1621);
  static const Color backgroundTop = Color(0xFF17212B);

  static const Color surface = Color(0xFF17212B);
  static const Color surfaceElevated = Color(0xFF1E2A36);
  static const Color surfaceSoft = Color(0xFF22303D);

  static const Color accent = Color(0xFF2EA6FF);
  static const Color accentSoft = Color(0xFF1F3D52);
  static const Color success = Color(0xFF58C77B);
  static const Color warning = Color(0xFFFFC857);
  static const Color danger = Color(0xFFFF6B6B);

  static const Color text = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFAEBAC6);
  static const Color textMuted = Color(0xFF7F91A4);

  static const Color divider = Color(0xFF2A3744);
  static const Color border = Color(0xFF263442);

  // Compatibility with old files
  static const Color button = accent;
  static const Color fieldFill = surfaceElevated;
  static const Color hint = textMuted;
  static const Color accentOlive = accent;
}

class AppRadii {
  AppRadii._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 18;
  static const double xl = 22;
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle pageTitle = TextStyle(
    color: AppColors.text,
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const TextStyle sectionTitle = TextStyle(
    color: AppColors.text,
    fontSize: 18,
    height: 1.22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.15,
  );

  static const TextStyle cardTitle = TextStyle(
    color: AppColors.text,
    fontSize: 16,
    height: 1.32,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle small = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle caption = TextStyle(
    color: AppColors.textMuted,
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );
}

final ThemeData appTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  fontFamily: null,

  scaffoldBackgroundColor: AppColors.background,

  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: Colors.white,

    secondary: AppColors.accent,
    onSecondary: Colors.white,

    error: AppColors.danger,
    onError: Colors.white,

    surface: AppColors.surface,
    onSurface: AppColors.text,

    surfaceVariant: AppColors.surfaceSoft,
    onSurfaceVariant: AppColors.textSecondary,

    primaryContainer: AppColors.accentSoft,
    onPrimaryContainer: AppColors.accent,

    secondaryContainer: AppColors.surfaceElevated,
    onSecondaryContainer: AppColors.text,

    background: AppColors.background,
    onBackground: AppColors.text,
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: AppTextStyles.pageTitle,
    iconTheme: IconThemeData(color: AppColors.text),
  ),

  cardTheme: CardThemeData(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      side: const BorderSide(color: AppColors.border),
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.surfaceSoft,
      disabledForegroundColor: AppColors.textMuted,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.text,
      disabledForegroundColor: AppColors.textMuted,
      side: const BorderSide(color: AppColors.border),
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.accent,
      disabledForegroundColor: AppColors.textMuted,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  ),

  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: AppColors.accent,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceElevated,
    hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
    labelStyle: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
    ),
  ),

  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      color: AppColors.text,
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.1,
    ),
    headlineSmall: AppTextStyles.pageTitle,
    titleLarge: AppTextStyles.sectionTitle,
    titleMedium: AppTextStyles.cardTitle,
    bodyLarge: AppTextStyles.body,
    bodyMedium: AppTextStyles.small,
    bodySmall: AppTextStyles.caption,
    labelLarge: TextStyle(
      color: AppColors.text,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
  ),

  dividerTheme: const DividerThemeData(
    color: AppColors.divider,
    thickness: 1,
    space: 1,
  ),

  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.surfaceElevated,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      side: const BorderSide(color: AppColors.border),
    ),
    titleTextStyle: AppTextStyles.sectionTitle,
    contentTextStyle: AppTextStyles.body,
  ),

  snackBarTheme: SnackBarThemeData(
    backgroundColor: AppColors.surfaceElevated,
    contentTextStyle: AppTextStyles.body.copyWith(color: AppColors.text),
    behavior: SnackBarBehavior.floating,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      side: const BorderSide(color: AppColors.border),
    ),
  ),

  listTileTheme: const ListTileThemeData(
    iconColor: AppColors.textSecondary,
    textColor: AppColors.text,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  ),

  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    modalBackgroundColor: Colors.transparent,
  ),

  datePickerTheme: DatePickerThemeData(
    backgroundColor: AppColors.surfaceElevated,
    surfaceTintColor: Colors.transparent,
    headerBackgroundColor: AppColors.surface,
    headerForegroundColor: AppColors.text,
    dayForegroundColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) return Colors.white;
      if (states.contains(MaterialState.disabled)) return AppColors.textMuted;
      return AppColors.text;
    }),
    dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) return AppColors.accent;
      return Colors.transparent;
    }),
    todayForegroundColor: const MaterialStatePropertyAll(AppColors.accent),
    todayBorder: const BorderSide(color: AppColors.accent),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
    ),
  ),
);

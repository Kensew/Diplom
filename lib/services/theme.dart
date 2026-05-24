// lib/services/theme.dart

import 'package:flutter/material.dart';

/// Базовая тёмная палитра с оливковым акцентом
class AppColors {
  /// Основной фон приложения (тёмный, с лёгким оливковым оттенком)
  static const Color background = Color(0xFF111510);

  /// Цвет кнопок / акцентный чёрный
  static const Color button = Color(0xFF0B0B0B);

  /// Фон полей ввода и карточек (если не через colorScheme)
  static const Color fieldFill = Color.fromRGBO(200, 210, 180, .08);

  /// Цвет текста-подсказки
  static const Color hint = Colors.white60;

  /// Основной цвет текста
  static const Color text = Colors.white;

  /// Мягкий оливковый акцент
  static const Color accentOlive = Color(0xFF9DB36B);
}

/// Единая тема приложения
final ThemeData appTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,

  scaffoldBackgroundColor: AppColors.background,

  colorScheme: ColorScheme.dark(
    primary: AppColors.button,
    onPrimary: AppColors.text,

    secondary: AppColors.accentOlive,
    onSecondary: AppColors.text,

    surface: const Color(0xFF141914),
    onSurface: AppColors.text,

    background: AppColors.background,
    onBackground: AppColors.text,

    // ВАЖНО: контейнеры, которые юзает CreateOrder
    primaryContainer: const Color(0xFF151A14), // фон экрана CreateOrder
    secondaryContainer: const Color(
      0xFF1C221B,
    ), // фон полей / карточек (тёмный, не ядёный)
    surfaceVariant: const Color(0xFF181E17),
  ),

  // AppBar
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: AppColors.text,
      fontSize: 22,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: IconThemeData(color: AppColors.text),
  ),

  // Карточки
  cardTheme: CardThemeData(
    color: const Color(0xFF181E17),
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    margin: EdgeInsets.zero,
  ),

  // Кнопки
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.button,
      foregroundColor: AppColors.text,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.text,
      side: const BorderSide(color: Colors.white24, width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.accentOlive,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
  ),

  // FAB
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.button,
    foregroundColor: AppColors.text,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
  ),

  // Поля ввода (глобально)
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.fieldFill,
    hintStyle: const TextStyle(color: AppColors.hint),
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide(color: AppColors.accentOlive, width: 1.2),
    ),
  ),

  // Текст
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColors.text, fontSize: 16),
    bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
    bodySmall: TextStyle(color: Colors.white60, fontSize: 12),
    headlineLarge: TextStyle(
      color: AppColors.text,
      fontSize: 28,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
    ),
    headlineSmall: TextStyle(
      color: AppColors.text,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      color: Colors.white70,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
  ),

  // Divider
  dividerTheme: const DividerThemeData(
    color: Colors.white10,
    thickness: 1,
    space: 24,
  ),

  // Диалоги
  dialogTheme: DialogThemeData(
    backgroundColor: const Color(0xFF151A14),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
    ),
    titleTextStyle: const TextStyle(
      color: AppColors.text,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    contentTextStyle: const TextStyle(color: Colors.white70, fontSize: 15),
  ),

  // SnackBar
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: AppColors.button,
    contentTextStyle: TextStyle(color: AppColors.text),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  ),

  listTileTheme: const ListTileThemeData(
    iconColor: AppColors.text,
    textColor: AppColors.text,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  ),
);

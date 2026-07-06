import 'package:flutter/material.dart';

/// IntelliJ IDEA Darcula-inspired color palette.
abstract final class IdeaColors {
  static const background = Color(0xFF2B2B2B);
  static const sidebar = Color(0xFF3C3F41);
  static const toolbar = Color(0xFF323232);
  static const panelBorder = Color(0xFF515658);
  static const selected = Color(0xFF214283);
  static const hover = Color(0xFF4B6EAF);
  static const accent = Color(0xFF4A9FF5);
  static const textPrimary = Color(0xFFBBBBBB);
  static const textSecondary = Color(0xFF808080);
  static const textBright = Color(0xFFE0E0E0);
  static const success = Color(0xFF629755);
  static const warning = Color(0xFFBBB529);
  static const error = Color(0xFFBC3F3C);
  static const inputBackground = Color(0xFF45494A);
}

abstract final class IdeaTheme {
  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      surface: IdeaColors.background,
      primary: IdeaColors.accent,
      secondary: IdeaColors.hover,
      error: IdeaColors.error,
      onSurface: IdeaColors.textPrimary,
      onPrimary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: IdeaColors.background,
      colorScheme: colorScheme,
      dividerColor: IdeaColors.panelBorder,
      fontFamily: 'Segoe UI',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: IdeaColors.textPrimary, fontSize: 13),
        bodySmall: TextStyle(color: IdeaColors.textSecondary, fontSize: 12),
        titleMedium: TextStyle(
          color: IdeaColors.textBright,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: IdeaColors.textBright,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: TextStyle(
          color: IdeaColors.textSecondary,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
      iconTheme: const IconThemeData(color: IdeaColors.textSecondary, size: 16),
      dividerTheme: const DividerThemeData(
        color: IdeaColors.panelBorder,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: IdeaColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: IdeaColors.panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: IdeaColors.panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: IdeaColors.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        hintStyle: const TextStyle(color: IdeaColors.textSecondary, fontSize: 13),
        labelStyle: const TextStyle(color: IdeaColors.textSecondary, fontSize: 12),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(color: IdeaColors.toolbar),
        textStyle: TextStyle(color: IdeaColors.textBright, fontSize: 12),
      ),
    );
  }
}

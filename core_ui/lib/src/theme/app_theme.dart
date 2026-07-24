import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.canvas,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.1, color: AppColors.ink),
          headlineMedium: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -.7, color: AppColors.ink),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
          bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: AppColors.ink),
          bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: AppColors.muted),
        ),
        appBarTheme: const AppBarTheme(elevation: 0, scrolledUnderElevation: 0, backgroundColor: AppColors.canvas),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.white, showDragHandle: true),
      );
}

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.secondarySkyBlue,
        surface: AppColors.backgroundLight,
      ),
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.titleLargeNoot,
        titleLarge: AppTextStyles.titleMediumNoot,
        bodyLarge: AppTextStyles.bodyLargeInter,
        bodyMedium: AppTextStyles.bodyMediumInter,
      ),
    );
  }
}
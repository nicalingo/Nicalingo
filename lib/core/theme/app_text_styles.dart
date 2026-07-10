import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Títulos principales usando la fuente Noot
  static const TextStyle titleLargeNoot = TextStyle(
    fontFamily: 'Noot',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryBlue,
  );

  static const TextStyle titleMediumNoot = TextStyle(
    fontFamily: 'Noot',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryBlue,
  );

  // Texto del cuerpo usando la fuente Inter
  static const TextStyle bodyLargeInter = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    color: AppColors.textDark,
  );

  static const TextStyle bodyMediumInter = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    color: AppColors.textDark,
  );

  // Estilo específico para los campos de texto o validaciones
  static const TextStyle inputTextStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    color: AppColors.textDark,
  );
}
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Monta o ThemeData do app a partir das cores e tipografia do
/// Bússola Design System. Nenhuma tela deve definir cor/fonte "na mão" —
/// sempre puxar daqui, para o app inteiro mudar junto se o Design System mudar.
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          error: AppColors.error,
          brightness: Brightness.light,
        ),
        textTheme: TextTheme(
          headlineMedium: AppTextStyles.heading1,
          headlineSmall: AppTextStyles.heading2,
          bodyLarge: AppTextStyles.body,
          bodyMedium: AppTextStyles.bodyMuted,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          error: AppColors.error,
          brightness: Brightness.dark,
        ),
        textTheme: TextTheme(
          headlineMedium: AppTextStyles.heading1.copyWith(color: AppColors.textDark),
          headlineSmall: AppTextStyles.heading2.copyWith(color: AppColors.textDark),
          bodyLarge: AppTextStyles.body.copyWith(color: AppColors.textDark),
          bodyMedium: AppTextStyles.bodyMuted,
        ),
      );
}

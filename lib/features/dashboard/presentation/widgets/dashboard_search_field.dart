import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';

/// Campo de busca da Hoje — nesta etapa é só visual: ainda não existe uma
/// busca de tarefas/metas no app pra ligar aqui.
class DashboardSearchField extends StatelessWidget {
  const DashboardSearchField({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: 'Buscar tarefa ou meta',
        hintStyle: AppTextStyles.bodyMuted,
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

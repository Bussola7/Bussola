import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/core/utils/date_formatting.dart';

/// Visualização "Mês": grade de semanas x dias, no estilo calendário
/// tradicional. Nesta etapa cada célula só mostra o número do dia — os
/// "pontinhos" de evento por baixo do número entram na Etapa 2.2.
class MonthView extends StatelessWidget {
  final DateTime focusedDate;

  const MonthView({super.key, required this.focusedDate});

  @override
  Widget build(BuildContext context) {
    final primeiroDiaMes = DateTime(focusedDate.year, focusedDate.month, 1);
    final inicioGrade = DateFormatting.inicioDaSemana(primeiroDiaMes);
    final hoje = DateFormatting.apenasData(DateTime.now());
    final totalCelulas = 42; // 6 semanas x 7 dias — cobre qualquer mês

    return Column(
      key: const PageStorageKey('month_view'),
      children: [
        Row(
          children: DateFormatting.diasSemanaAbrev
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d.toUpperCase(), style: AppTextStyles.bodyMuted.copyWith(fontSize: 11)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemCount: totalCelulas,
            itemBuilder: (context, i) {
              final dia = inicioGrade.add(Duration(days: i));
              final foraDoMes = dia.month != focusedDate.month;
              final isHoje = DateFormatting.isMesmoDia(dia, hoje);

              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isHoje ? AppColors.primary.withOpacity(0.08) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${dia.day}',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: foraDoMes
                          ? AppColors.textMuted.withOpacity(0.4)
                          : (isHoje ? AppColors.primary : AppColors.textLight),
                      fontWeight: isHoje ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

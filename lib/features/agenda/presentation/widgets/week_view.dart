import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/core/utils/date_formatting.dart';

/// Visualização "Semana": cabeçalho com os 7 dias da semana e uma grade
/// por baixo. Nesta etapa ainda não desenha nenhum evento — só a estrutura
/// de colunas que a Etapa 2.2 vai preencher.
class WeekView extends StatelessWidget {
  final DateTime focusedDate;

  const WeekView({super.key, required this.focusedDate});

  @override
  Widget build(BuildContext context) {
    final inicioSemana = DateFormatting.inicioDaSemana(focusedDate);
    final dias = List.generate(7, (i) => inicioSemana.add(Duration(days: i)));
    final hoje = DateFormatting.apenasData(DateTime.now());

    return Column(
      key: const PageStorageKey('week_view'),
      children: [
        Row(
          children: dias.map((dia) {
            final isHoje = DateFormatting.isMesmoDia(dia, hoje);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      DateFormatting.diasSemanaAbrev[dia.weekday % 7].toUpperCase(),
                      style: AppTextStyles.bodyMuted.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isHoje ? AppColors.primary : Colors.transparent,
                      child: Text(
                        '${dia.day}',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          color: isHoje ? Colors.white : AppColors.textLight,
                          fontWeight: isHoje ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: AppColors.backgroundLight, width: i == 0 ? 0 : 1)),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

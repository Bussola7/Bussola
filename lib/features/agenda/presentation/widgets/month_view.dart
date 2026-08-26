import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/core/utils/date_formatting.dart';
import 'package:bussola/features/agenda/presentation/providers/event_provider.dart';

/// Visualização "Mês": grade de semanas x dias, no estilo calendário
/// tradicional. Dias com pelo menos um compromisso ficam com fundo na cor
/// primária — o resto da célula (número, "hoje") continua como antes.
class MonthView extends ConsumerWidget {
  final DateTime focusedDate;

  const MonthView({super.key, required this.focusedDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primeiroDiaMes = DateTime(focusedDate.year, focusedDate.month, 1);
    final inicioGrade = DateFormatting.inicioDaSemana(primeiroDiaMes);
    final hoje = DateFormatting.apenasData(DateTime.now());
    final totalCelulas = 42; // 6 semanas x 7 dias — cobre qualquer mês

    final eventos = ref.watch(eventNotifierProvider).events;
    final diasComEvento = eventos
        .where((e) => !e.isDeleted)
        .map((e) => DateFormatting.apenasData(e.startDatetime.toLocal()))
        .toSet();

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
              final diaSemHora = DateFormatting.apenasData(dia);
              final foraDoMes = dia.month != focusedDate.month;
              final isHoje = DateFormatting.isMesmoDia(dia, hoje);
              final temEvento = diasComEvento.contains(diaSemHora);

              Color? corFundo;
              Border? borda;
              Color corTexto;
              FontWeight peso;

              if (temEvento) {
                corFundo = AppColors.primaryStrong;
                corTexto = Colors.white;
                peso = FontWeight.w700;
                if (isHoje) borda = Border.all(color: Colors.white, width: 2);
              } else if (isHoje) {
                corFundo = AppColors.primary.withOpacity(0.08);
                corTexto = AppColors.primary;
                peso = FontWeight.w700;
              } else {
                corTexto = foraDoMes ? AppColors.textMuted.withOpacity(0.4) : AppColors.textLight;
                peso = FontWeight.w400;
              }

              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: corFundo,
                  border: borda,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${dia.day}',
                    style: AppTextStyles.body.copyWith(fontSize: 13, color: corTexto, fontWeight: peso),
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

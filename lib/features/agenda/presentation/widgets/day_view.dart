import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';

/// Visualização "Dia": uma linha do tempo de hora em hora, de 00h a 23h.
/// Nesta etapa é só a grade — nenhum evento é desenhado ainda (entra na
/// Etapa 2.2, quando o `EventNotifier` for plugado aqui).
class DayView extends StatelessWidget {
  final DateTime focusedDate;

  const DayView({super.key, required this.focusedDate});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const PageStorageKey('day_view'),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: 24,
      itemBuilder: (context, hora) {
        return SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Text(
                    '${hora.toString().padLeft(2, '0')}:00',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.bodyMuted.copyWith(fontSize: 12),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.backgroundLight, width: 1)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

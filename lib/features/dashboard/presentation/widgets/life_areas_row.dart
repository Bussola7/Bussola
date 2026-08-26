import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/dashboard/presentation/screens/area_detail_screen.dart';
import 'package:bussola/shared/models/life_area.dart';

/// As 4 áreas de vida da Hoje — Saúde, Trabalho, Pessoal, Estudos. Ao
/// tocar, abre a tela dedicada daquela área ([AreaDetailScreen]) com as
/// tarefas/compromissos/objetivos filtrados. "Financeiro" existe no
/// enum `LifeArea` mas não tem botão aqui.
class LifeAreasRow extends StatelessWidget {
  final String userId;

  const LifeAreasRow({super.key, required this.userId});

  static const _areasExibidas = [LifeArea.saude, LifeArea.trabalho, LifeArea.pessoal, LifeArea.estudos];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _areasExibidas
          .map((area) => _AreaIcon(
                area: area,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AreaDetailScreen(area: area, userId: userId)),
                ),
              ))
          .toList(),
    );
  }
}

class _AreaIcon extends StatelessWidget {
  final LifeArea area;
  final VoidCallback onTap;

  const _AreaIcon({required this.area, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: area.backgroundColor, shape: BoxShape.circle),
            child: Icon(area.icon, color: area.color),
          ),
          const SizedBox(height: 6),
          Text(area.label, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/shared/models/life_area.dart';

/// As 5 áreas de vida da Hoje. Não navega sozinha pra lugar nenhum —
/// quem decide o que fazer com o toque é [onTapArea] (a Hoje mostra um
/// menu escolhendo Tarefas/Agenda/Objetivos daquela área). Rola
/// horizontalmente — com 5 ícones + label, nem toda tela estreita cabe
/// tudo sem cortar.
class LifeAreasRow extends StatelessWidget {
  final ValueChanged<LifeArea> onTapArea;

  const LifeAreasRow({super.key, required this.onTapArea});

  static const _areasExibidas = [
    LifeArea.saude,
    LifeArea.trabalho,
    LifeArea.pessoal,
    LifeArea.estudos,
    LifeArea.financeiro,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final area in _areasExibidas) ...[
            _AreaIcon(area: area, onTap: () => onTapArea(area)),
            if (area != _areasExibidas.last) const SizedBox(width: 16),
          ],
        ],
      ),
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
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: area.backgroundColor, shape: BoxShape.circle),
              child: Icon(area.icon, color: area.color),
            ),
            const SizedBox(height: 6),
            Text(area.label, style: AppTextStyles.bodyMuted.copyWith(fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

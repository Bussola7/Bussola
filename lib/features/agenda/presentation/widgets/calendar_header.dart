import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';
import 'package:bussola/core/theme/app_text_styles.dart';
import 'package:bussola/features/agenda/presentation/state/calendar_ui_state.dart';

/// Cabeçalho do calendário: título da data em foco (muda de formato
/// conforme o modo), botões de anterior/hoje/próximo, e o seletor dos
/// 4 modos de visualização. Widget "burro" — só chama os callbacks que
/// recebe, quem decide o que fazer é o `CalendarUiNotifier`.
class CalendarHeader extends StatelessWidget {
  final String title;
  final CalendarViewMode viewMode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<CalendarViewMode> onViewModeChanged;

  const CalendarHeader({
    super.key,
    required this.title,
    required this.viewMode,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    style: AppTextStyles.heading2,
                  ),
                ),
              ),
              _NavIconButton(icon: Icons.chevron_left, tooltip: 'Anterior', onPressed: onPrevious),
              const SizedBox(width: 4),
              TextButton(
                onPressed: onToday,
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                child: const Text('Hoje'),
              ),
              const SizedBox(width: 4),
              _NavIconButton(icon: Icons.chevron_right, tooltip: 'Próximo', onPressed: onNext),
            ],
          ),
          const SizedBox(height: 12),
          _ViewModeSwitcher(current: viewMode, onChanged: onViewModeChanged),
        ],
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _NavIconButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      color: AppColors.textMuted,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ViewModeSwitcher extends StatelessWidget {
  final CalendarViewMode current;
  final ValueChanged<CalendarViewMode> onChanged;

  const _ViewModeSwitcher({required this.current, required this.onChanged});

  static const _labels = {
    CalendarViewMode.dia: 'Dia',
    CalendarViewMode.semana: 'Semana',
    CalendarViewMode.mes: 'Mês',
    CalendarViewMode.lista: 'Lista',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: CalendarViewMode.values.map((mode) {
          final isSelected = mode == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surfaceLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Text(
                  _labels[mode]!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMuted.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

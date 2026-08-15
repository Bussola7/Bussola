import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';

/// FAB circular do Design System. Sempre visível, sombra discreta, e uma
/// pequena redução de escala ao ser pressionado — dá o "feedback" tátil
/// sem precisar de nenhum pacote externo de animação.
class BussolaFab extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;

  const BussolaFab({super.key, required this.onPressed, this.icon = Icons.add, this.tooltip = 'Criar compromisso'});

  @override
  State<BussolaFab> createState() => _BussolaFabState();
}

class _BussolaFabState extends State<BussolaFab> {
  double _scale = 1.0;

  void _setPressed(bool pressed) => setState(() => _scale = pressed ? 0.9 : 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Tooltip(
          message: widget.tooltip,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Icon(widget.icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

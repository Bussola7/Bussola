import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';

/// Indicador de carregamento padrão do app. Usar sempre este componente
/// em vez de um CircularProgressIndicator solto, para manter a cor e o
/// tamanho consistentes em todas as telas.
class LoadingState extends StatelessWidget {
  final String? message;

  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: const TextStyle(color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

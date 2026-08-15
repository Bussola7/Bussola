import 'package:flutter/material.dart';
import 'package:bussola/core/components/empty_state.dart';

/// Placeholder da aba "IA". O assistente inteligente de verdade (com
/// modelo de linguagem) entra em sprint futura — esta etapa (2.4) só
/// prepara a estrutura de pastas (`domain/`, `data/`, `presentation/`)
/// para quando isso for implementado; nenhuma lógica de IA existe ainda.
class AiPlaceholderScreen extends StatelessWidget {
  const AiPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.auto_awesome_outlined,
      title: 'Seu assistente inteligente',
      message: 'Em breve a IA vai te ajudar a planejar melhor seu tempo com base nas suas preferências.',
    );
  }
}

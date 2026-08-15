import 'package:flutter/material.dart';
import 'package:bussola/core/components/empty_state.dart';

/// Placeholder da aba "Criar". A criação de eventos/tarefas entra
/// em sprint futura — esta tela só marca o lugar dela na navegação.
class CreateEventPlaceholderScreen extends StatelessWidget {
  const CreateEventPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.add_circle_outline,
      title: 'Criar compromissos e tarefas',
      message: 'Em breve você vai poder criar eventos, tarefas e metas direto por aqui.',
    );
  }
}

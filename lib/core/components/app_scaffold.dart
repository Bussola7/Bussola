import 'package:flutter/material.dart';
import 'bottom_navigation.dart';

/// Estrutura base de todas as telas principais do app: cuida do fundo,
/// da barra superior (opcional) e da navegação inferior (opcional).
/// Assim nenhuma tela precisa remontar isso na mão — só preenche o [body].
class AppScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final int? currentNavIndex;
  final ValueChanged<int>? onNavTap;
  final List<Widget>? actions;
  final bool showBackButton;

  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.currentNavIndex,
    this.onNavTap,
    this.actions,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              automaticallyImplyLeading: showBackButton,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: actions,
            ),
      body: SafeArea(child: body),
      bottomNavigationBar: currentNavIndex == null
          ? null
          : AppBottomNavigation(currentIndex: currentNavIndex!, onTap: onNavTap!),
    );
  }
}

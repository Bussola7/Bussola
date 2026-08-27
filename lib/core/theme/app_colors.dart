import 'package:flutter/material.dart';

/// Paleta oficial do Bússola Design System.
/// Qualquer nova cor do app deve ser adicionada aqui — nunca direto na tela.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryStrong = Color(0xFF1D4ED8);
  static const Color secondary = Color(0xFF10B981);
  static const Color accent = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF0F172A);

  static const Color textLight = Color(0xFF0F172A);
  static const Color textDark = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF64748B);

  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E293B);

  /// Fundo de cartões escuros sobre superfície clara (ex: botão de
  /// "Relatórios" na Hoje) — mesmo tom do [surfaceDark], nomeado à parte
  /// porque aqui o uso é decorativo, não de tema escuro.
  static const Color cardDark = Color(0xFF1E293B);

  /// Gradiente do header da tela Hoje.
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Cores das áreas de vida (`LifeArea`) — ícone cheio + fundo claro do
  /// mesmo tom. Usadas na seção "Áreas da vida" da Hoje e no header da
  /// tela de detalhe de cada área.
  static const Color lifeAreaSaude = Color(0xFF10B981);
  static const Color lifeAreaSaudeBg = Color(0xFFD1FAE5);
  static const Color lifeAreaTrabalho = Color(0xFF2563EB);
  static const Color lifeAreaTrabalhoBg = Color(0xFFDBEAFE);
  static const Color lifeAreaPessoal = Color(0xFF9D174D);
  static const Color lifeAreaPessoalBg = Color(0xFFFCE7F3);
  static const Color lifeAreaEstudos = Color(0xFFD97706);
  static const Color lifeAreaEstudosBg = Color(0xFFFEF3C7);
  /// Verde-dinheiro — deliberadamente diferente do verde-esmeralda de
  /// `lifeAreaSaude` e do dourado de `lifeAreaEstudos`, pra não confundir
  /// visualmente ao lado das outras 4.
  static const Color lifeAreaFinanceiro = Color(0xFF16A34A);
  static const Color lifeAreaFinanceiroBg = Color(0xFFDCFCE7);
}

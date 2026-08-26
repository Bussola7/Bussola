import 'package:flutter/material.dart';
import 'package:bussola/core/theme/app_colors.dart';

/// As 5 áreas de vida que o Bússola organiza — usado por Tarefas,
/// Objetivos e Agenda, para a pessoa ver de relance em qual parte da
/// vida cada item está.
///
/// "Trabalho" substituiu "Profissional" (migração `0008` renomeia os
/// dados salvos também, não é só troca de rótulo). "Estudos" é área
/// nova. "Financeiro" continua existindo no banco, mas não tem ícone
/// próprio na seção "Áreas da vida" da tela Hoje — só chega até ele por
/// Tarefas/Objetivos diretamente.
enum LifeArea { saude, trabalho, pessoal, estudos, financeiro }

extension LifeAreaX on LifeArea {
  static LifeArea fromDb(String value) {
    switch (value) {
      case 'trabalho':
        return LifeArea.trabalho;
      case 'saude':
        return LifeArea.saude;
      case 'financeiro':
        return LifeArea.financeiro;
      case 'estudos':
        return LifeArea.estudos;
      case 'pessoal':
      default:
        return LifeArea.pessoal;
    }
  }

  String toDb() {
    switch (this) {
      case LifeArea.trabalho:
        return 'trabalho';
      case LifeArea.saude:
        return 'saude';
      case LifeArea.financeiro:
        return 'financeiro';
      case LifeArea.estudos:
        return 'estudos';
      case LifeArea.pessoal:
        return 'pessoal';
    }
  }

  String get label {
    switch (this) {
      case LifeArea.trabalho:
        return 'Trabalho';
      case LifeArea.saude:
        return 'Saúde';
      case LifeArea.financeiro:
        return 'Financeiro';
      case LifeArea.estudos:
        return 'Estudos';
      case LifeArea.pessoal:
        return 'Pessoal';
    }
  }

  /// Emoji simples usado nas listas — evita depender de um ícone
  /// específico do Material por área, mais leve visualmente.
  ///
  /// Escrito como escape Unicode (`\u{...}`), não como o caractere cru:
  /// isso evita qualquer problema de codificação do arquivo entre
  /// sistemas operacionais diferentes (o texto do emoji em si nunca
  /// precisa ser salvo/lido como bytes especiais).
  String get emoji {
    switch (this) {
      case LifeArea.trabalho:
        return '\u{1F4BC}'; // maleta
      case LifeArea.saude:
        return '\u{1FA7A}'; // estetoscópio
      case LifeArea.financeiro:
        return '\u{1F4B0}'; // saco de dinheiro
      case LifeArea.estudos:
        return '\u{1F393}'; // capelo de formatura
      case LifeArea.pessoal:
        return '\u{1F331}'; // muda de planta
    }
  }

  /// Ícone Material da área — usado na seção "Áreas da vida" da Hoje e
  /// no header da tela de detalhe.
  IconData get icon {
    switch (this) {
      case LifeArea.trabalho:
        return Icons.work_outline;
      case LifeArea.saude:
        return Icons.favorite_outline;
      case LifeArea.financeiro:
        return Icons.attach_money;
      case LifeArea.estudos:
        return Icons.school_outlined;
      case LifeArea.pessoal:
        return Icons.person_outline;
    }
  }

  Color get color {
    switch (this) {
      case LifeArea.trabalho:
        return AppColors.lifeAreaTrabalho;
      case LifeArea.saude:
        return AppColors.lifeAreaSaude;
      case LifeArea.financeiro:
        return AppColors.lifeAreaFinanceiro;
      case LifeArea.estudos:
        return AppColors.lifeAreaEstudos;
      case LifeArea.pessoal:
        return AppColors.lifeAreaPessoal;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case LifeArea.trabalho:
        return AppColors.lifeAreaTrabalhoBg;
      case LifeArea.saude:
        return AppColors.lifeAreaSaudeBg;
      case LifeArea.financeiro:
        return AppColors.lifeAreaFinanceiroBg;
      case LifeArea.estudos:
        return AppColors.lifeAreaEstudosBg;
      case LifeArea.pessoal:
        return AppColors.lifeAreaPessoalBg;
    }
  }
}

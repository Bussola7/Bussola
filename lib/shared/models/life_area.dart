/// As 4 áreas de vida que o Bússola organiza — usado por Tarefas e
/// Objetivos, para a pessoa ver de relance em qual parte da vida cada
/// item está.
enum LifeArea { profissional, saude, financeiro, pessoal }

extension LifeAreaX on LifeArea {
  static LifeArea fromDb(String value) {
    switch (value) {
      case 'profissional':
        return LifeArea.profissional;
      case 'saude':
        return LifeArea.saude;
      case 'financeiro':
        return LifeArea.financeiro;
      case 'pessoal':
      default:
        return LifeArea.pessoal;
    }
  }

  String toDb() {
    switch (this) {
      case LifeArea.profissional:
        return 'profissional';
      case LifeArea.saude:
        return 'saude';
      case LifeArea.financeiro:
        return 'financeiro';
      case LifeArea.pessoal:
        return 'pessoal';
    }
  }

  String get label {
    switch (this) {
      case LifeArea.profissional:
        return 'Profissional';
      case LifeArea.saude:
        return 'Saúde';
      case LifeArea.financeiro:
        return 'Financeiro';
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
      case LifeArea.profissional:
        return '\u{1F4BC}'; // maleta
      case LifeArea.saude:
        return '\u{1FA7A}'; // estetoscópio
      case LifeArea.financeiro:
        return '\u{1F4B0}'; // saco de dinheiro
      case LifeArea.pessoal:
        return '\u{1F331}'; // muda de planta
    }
  }
}

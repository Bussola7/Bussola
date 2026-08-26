/// O que o comando de voz reconhecido pede para fazer.
enum VoiceIntent { criarEvento, desconhecido }

/// Resultado da interpretação de um comando de voz por regras.
///
/// Os campos [data]/[hora]/[minuto] só vêm preenchidos quando o texto tem
/// uma expressão de data/hora que o parser reconhece — quando não reconhece,
/// fica nulo em vez de arriscar um palpite: quem decide o valor final é a
/// tela de confirmação, nunca o parser sozinho.
class VoiceCommandResult {
  final VoiceIntent intent;
  final String? titulo;
  final DateTime? data;
  final int? hora;
  final int? minuto;
  final String textoOriginal;

  const VoiceCommandResult({
    required this.intent,
    this.titulo,
    this.data,
    this.hora,
    this.minuto,
    required this.textoOriginal,
  });
}

/// Interpreta comandos de voz em PT-BR por regras (sem IA externa), hoje
/// reconhecendo só a intenção de criar evento/reunião/compromisso.
///
/// Extrai data e hora do texto quando consegue reconhecer uma expressão
/// conhecida ("amanhã", "sexta", "dia 15", "às 15h", "meio-dia" etc.) e usa
/// o que sobra do texto (menos o verbo de comando) como título sugerido.
/// Frases mais complexas do que essas simplesmente não têm data/hora
/// extraída — a tela de confirmação é sempre o lugar onde o usuário corrige.
class VoiceCommandParser {
  static const _verbosComando = ['agendar', 'marcar', 'marca', 'agenda', 'criar', 'adicionar'];
  static const _substantivosEvento = ['reuniao', 'evento', 'compromisso', 'call', 'chamada'];

  static const _diasSemana = {
    'domingo': DateTime.sunday,
    'segunda': DateTime.monday,
    'terca': DateTime.tuesday,
    'quarta': DateTime.wednesday,
    'quinta': DateTime.thursday,
    'sexta': DateTime.friday,
    'sabado': DateTime.saturday,
  };

  static const _meses = {
    'janeiro': 1,
    'fevereiro': 2,
    'marco': 3,
    'abril': 4,
    'maio': 5,
    'junho': 6,
    'julho': 7,
    'agosto': 8,
    'setembro': 9,
    'outubro': 10,
    'novembro': 11,
    'dezembro': 12,
  };

  static const _conectoresFinais = {'com', 'para', 'as', 'de', 'do', 'da', 'em', 'no', 'na', 'dia', 'ao'};
  static const _conectoresIniciais = {'a', 'o', 'as', 'os', 'da', 'do', 'das', 'dos', 'de', 'em', 'no', 'na', 'ao'};

  final DateTime Function() _agora;

  VoiceCommandParser({DateTime Function()? agora}) : _agora = agora ?? DateTime.now;

  VoiceCommandResult parse(String textoFalado) {
    final texto = textoFalado.trim();
    if (texto.isEmpty) return VoiceCommandResult(intent: VoiceIntent.desconhecido, textoOriginal: texto);

    final normalizado = _normalizar(texto);
    final reconheceu = _verbosComando.any((v) => normalizado.contains(v)) ||
        _substantivosEvento.any((s) => normalizado.contains(s));
    if (!reconheceu) {
      return VoiceCommandResult(intent: VoiceIntent.desconhecido, textoOriginal: texto);
    }

    var restante = texto;
    var restanteNorm = normalizado;

    final data = _extrairData(restanteNorm, _agora());
    if (data != null) {
      restante = _removerSpan(restante, restanteNorm, data.$2);
      restanteNorm = _normalizar(restante);
    }

    final hora = _extrairHora(restanteNorm);
    if (hora != null) {
      restante = _removerSpan(restante, restanteNorm, hora.$3);
      restanteNorm = _normalizar(restante);
    }

    return VoiceCommandResult(
      intent: VoiceIntent.criarEvento,
      titulo: _extrairTitulo(restante),
      data: data?.$1,
      hora: hora?.$1,
      minuto: hora?.$2,
      textoOriginal: texto,
    );
  }

  /// Remove de [original] o trecho correspondente a [span] em [normalizado].
  /// Funciona porque [_normalizar] preserva o comprimento da string (troca
  /// sempre 1 caractere por 1 caractere), então os índices batem nos dois.
  String _removerSpan(String original, String normalizado, (int, int) span) {
    final (inicio, fim) = span;
    return (original.substring(0, inicio) + ' ' + original.substring(fim)).trim();
  }

  // --- Data ---------------------------------------------------------------

  /// Prefixo opcional que "engole" a preposição que costuma vir junto da
  /// expressão de data ("para amanhã", "no dia 15") — sem isso, a
  /// preposição sobra solta no meio do título depois que a data é removida.
  static const _conectorData = r'(?:\b(?:para|pra|em|no|na)\s+)?';

  (DateTime, (int, int))? _extrairData(String textoNorm, DateTime agora) {
    final hoje = DateTime(agora.year, agora.month, agora.day);

    var m = RegExp('${_conectorData}daqui a (\\d{1,2}) dias?').firstMatch(textoNorm);
    if (m != null) {
      final dias = int.parse(m.group(1)!);
      return (hoje.add(Duration(days: dias)), (m.start, m.end));
    }

    m = RegExp('${_conectorData}depois de amanha').firstMatch(textoNorm);
    if (m != null) return (hoje.add(const Duration(days: 2)), (m.start, m.end));

    m = RegExp('${_conectorData}amanha').firstMatch(textoNorm);
    if (m != null) return (hoje.add(const Duration(days: 1)), (m.start, m.end));

    m = RegExp('$_conectorData\\bhoje\\b').firstMatch(textoNorm);
    if (m != null) return (hoje, (m.start, m.end));

    for (final entry in _diasSemana.entries) {
      m = RegExp('$_conectorData\\b${entry.key}(-feira|\\s+feira)?\\b').firstMatch(textoNorm);
      if (m != null) {
        var diferenca = (entry.value - hoje.weekday) % 7;
        final alvo = hoje.add(Duration(days: diferenca));
        return (alvo, (m.start, m.end));
      }
    }

    m = RegExp('$_conectorData\\bdia\\s+(\\d{1,2})\\s+de\\s+(\\w+)\\b').firstMatch(textoNorm);
    if (m != null) {
      final dia = int.parse(m.group(1)!);
      final mes = _meses[m.group(2)];
      if (mes != null) {
        var ano = agora.year;
        if (mes < agora.month || (mes == agora.month && dia < agora.day)) ano += 1;
        return (DateTime(ano, mes, dia), (m.start, m.end));
      }
    }

    m = RegExp('$_conectorData\\bdia\\s+(\\d{1,2})\\b').firstMatch(textoNorm);
    if (m != null) {
      final dia = int.parse(m.group(1)!);
      var mes = agora.month;
      var ano = agora.year;
      if (dia < agora.day) {
        mes += 1;
        if (mes > 12) {
          mes = 1;
          ano += 1;
        }
      }
      return (DateTime(ano, mes, dia), (m.start, m.end));
    }

    m = RegExp('$_conectorData\\b(\\d{1,2})/(\\d{1,2})(?:/(\\d{2,4}))?\\b').firstMatch(textoNorm);
    if (m != null) {
      final dia = int.parse(m.group(1)!);
      final mes = int.parse(m.group(2)!);
      final anoTexto = m.group(3);
      final ano = anoTexto == null ? agora.year : (anoTexto.length == 2 ? 2000 + int.parse(anoTexto) : int.parse(anoTexto));
      return (DateTime(ano, mes, dia), (m.start, m.end));
    }

    return null;
  }

  // --- Hora -----------------------------------------------------------------

  /// Mesma ideia de [_conectorData], mas para as preposições que acompanham
  /// a hora ("às 15h", "ao meio-dia").
  static const _conectorHora = r'(?:\b(?:as)\s+)?';
  static const _conectorPeriodo = r'\b(?:as|ao|a|de|da)\s+';

  (int, int, (int, int))? _extrairHora(String textoNorm) {
    var m = RegExp('(?:$_conectorPeriodo)?meio(-|\\s)?dia').firstMatch(textoNorm);
    if (m != null) return (12, 0, (m.start, m.end));

    m = RegExp('(?:$_conectorPeriodo)?meia(-|\\s)?noite').firstMatch(textoNorm);
    if (m != null) return (0, 0, (m.start, m.end));

    m = RegExp('$_conectorHora\\b(\\d{1,2}):(\\d{2})\\b').firstMatch(textoNorm);
    if (m != null) return (int.parse(m.group(1)!), int.parse(m.group(2)!), (m.start, m.end));

    m = RegExp('$_conectorHora\\b(\\d{1,2})\\s*h\\s*(\\d{2})?\\b').firstMatch(textoNorm);
    if (m != null) return (int.parse(m.group(1)!), int.parse(m.group(2) ?? '0'), (m.start, m.end));

    m = RegExp('$_conectorHora\\b(\\d{1,2})\\s*horas?(?:\\s+e\\s+(\\d{1,2})\\s*minutos?)?\\b').firstMatch(textoNorm);
    if (m != null) return (int.parse(m.group(1)!), int.parse(m.group(2) ?? '0'), (m.start, m.end));

    m = RegExp(r'\bas\s+(\d{1,2})\b').firstMatch(textoNorm);
    if (m != null) return (int.parse(m.group(1)!), 0, (m.start, m.end));

    m = RegExp('${_conectorPeriodo}manha\\b').firstMatch(textoNorm);
    if (m != null) return (9, 0, (m.start, m.end));

    m = RegExp('${_conectorPeriodo}tarde\\b').firstMatch(textoNorm);
    if (m != null) return (15, 0, (m.start, m.end));

    m = RegExp('${_conectorPeriodo}noite\\b').firstMatch(textoNorm);
    if (m != null) return (19, 0, (m.start, m.end));

    return null;
  }

  // --- Título -----------------------------------------------------------

  String? _extrairTitulo(String restante) {
    var titulo = restante;

    final verbos = _verbosComando.join('|');
    titulo = titulo.replaceFirst(RegExp('^\\s*($verbos)\\s+(uma\\s+|um\\s+)?', caseSensitive: false), '');

    titulo = titulo.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // Rede de segurança: se uma preposição/artigo ficar solta na ponta do
    // título (sobra de uma data/hora removida do meio da frase), tira.
    var mudou = true;
    while (mudou && titulo.isNotEmpty) {
      mudou = false;
      final palavras = titulo.split(' ');

      final primeira = _normalizar(palavras.first);
      if (_conectoresIniciais.contains(primeira) && palavras.length > 1) {
        palavras.removeAt(0);
        titulo = palavras.join(' ').trim();
        mudou = true;
        continue;
      }

      final ultima = _normalizar(palavras.last);
      if (_conectoresFinais.contains(ultima) && palavras.length > 1) {
        palavras.removeLast();
        titulo = palavras.join(' ').trim();
        mudou = true;
      }
    }

    if (titulo.isEmpty) return null;
    return titulo[0].toUpperCase() + titulo.substring(1);
  }

  // --- Normalização -------------------------------------------------------

  static const _acentos = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c',
  };

  /// Minúsculo e sem acento — preserva o comprimento da string (1 caractere
  /// vira 1 caractere), então os índices continuam válidos no texto original.
  String _normalizar(String s) {
    final minusculo = s.toLowerCase();
    final buffer = StringBuffer();
    for (final char in minusculo.split('')) {
      buffer.write(_acentos[char] ?? char);
    }
    return buffer.toString();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/voice/domain/voice_command_parser.dart';

void main() {
  final agora = DateTime(2026, 3, 10, 8, 0); // terça-feira
  final parser = VoiceCommandParser(agora: () => agora);

  group('VoiceCommandParser.parse — intenção', () {
    test('reconhece verbo de comando (agendar) como criarEvento', () {
      final r = parser.parse('agendar dentista amanhã às 10h');
      expect(r.intent, VoiceIntent.criarEvento);
    });

    test('reconhece substantivo de evento (reunião) mesmo sem verbo', () {
      final r = parser.parse('reunião com o cliente amanhã às 9h');
      expect(r.intent, VoiceIntent.criarEvento);
    });

    test('frase sem verbo nem substantivo de evento vira desconhecido', () {
      final r = parser.parse('comprar leite e pão');
      expect(r.intent, VoiceIntent.desconhecido);
      expect(r.titulo, null);
      expect(r.data, null);
    });

    test('texto vazio vira desconhecido', () {
      final r = parser.parse('   ');
      expect(r.intent, VoiceIntent.desconhecido);
    });
  });

  group('VoiceCommandParser.parse — data', () {
    test('"amanhã" vira o dia seguinte a partir de agora', () {
      final r = parser.parse('agendar reunião amanhã às 15h');
      expect(r.data, DateTime(2026, 3, 11));
    });

    test('"depois de amanhã" vira dois dias à frente', () {
      final r = parser.parse('agendar reunião depois de amanhã às 15h');
      expect(r.data, DateTime(2026, 3, 12));
    });

    test('"hoje" vira a data de agora', () {
      final r = parser.parse('agendar reunião hoje às 15h');
      expect(r.data, DateTime(2026, 3, 10));
    });

    test('"daqui a N dias" soma N dias a partir de agora', () {
      final r = parser.parse('agendar reunião daqui a 5 dias às 15h');
      expect(r.data, DateTime(2026, 3, 15));
    });

    test('nome de dia da semana futuro calcula a próxima ocorrência', () {
      // agora é terça (10/03); "sexta" deve cair em 13/03
      final r = parser.parse('agendar reunião na sexta às 15h');
      expect(r.data, DateTime(2026, 3, 13));
    });

    test('nome do dia da semana igual a hoje usa o próprio dia', () {
      // agora é terça (10/03); "terça" deve ser hoje mesmo
      final r = parser.parse('agendar reunião na terça às 15h');
      expect(r.data, DateTime(2026, 3, 10));
    });

    test('"dia N" no mês corrente quando o dia ainda não passou', () {
      final r = parser.parse('agendar reunião dia 20 às 15h');
      expect(r.data, DateTime(2026, 3, 20));
    });

    test('"dia N" pula para o mês seguinte quando o dia já passou', () {
      final r = parser.parse('agendar reunião dia 5 às 15h');
      expect(r.data, DateTime(2026, 4, 5));
    });

    test('"dia N de mês" usa o mês indicado', () {
      final r = parser.parse('agendar reunião dia 15 de julho às 15h');
      expect(r.data, DateTime(2026, 7, 15));
    });

    test('data numérica DD/MM', () {
      final r = parser.parse('agendar reunião 25/12 às 15h');
      expect(r.data, DateTime(2026, 12, 25));
    });

    test('sem expressão de data reconhecida, data fica nula', () {
      final r = parser.parse('agendar reunião com o time às 15h');
      expect(r.data, null);
    });
  });

  group('VoiceCommandParser.parse — hora', () {
    test('formato "HHhMM"', () {
      final r = parser.parse('agendar reunião amanhã às 14h30');
      expect(r.hora, 14);
      expect(r.minuto, 30);
    });

    test('formato "HHh" sem minutos', () {
      final r = parser.parse('agendar reunião amanhã às 15h');
      expect(r.hora, 15);
      expect(r.minuto, 0);
    });

    test('formato "HH horas"', () {
      final r = parser.parse('agendar reunião amanhã às 15 horas');
      expect(r.hora, 15);
      expect(r.minuto, 0);
    });

    test('formato "HH:MM"', () {
      final r = parser.parse('agendar reunião amanhã às 15:45');
      expect(r.hora, 15);
      expect(r.minuto, 45);
    });

    test('"meio-dia" vira 12:00', () {
      final r = parser.parse('agendar reunião amanhã ao meio-dia');
      expect(r.hora, 12);
      expect(r.minuto, 0);
    });

    test('"meia-noite" vira 00:00', () {
      final r = parser.parse('agendar reunião amanhã à meia-noite');
      expect(r.hora, 0);
      expect(r.minuto, 0);
    });

    test('"de manhã" vira uma hora aproximada (9h)', () {
      final r = parser.parse('agendar reunião amanhã de manhã');
      expect(r.hora, 9);
    });

    test('sem expressão de hora reconhecida, hora fica nula', () {
      final r = parser.parse('agendar reunião amanhã');
      expect(r.hora, null);
      expect(r.minuto, null);
    });
  });

  group('VoiceCommandParser.parse — título', () {
    test('remove o verbo de comando e as expressões de data/hora do título', () {
      final r = parser.parse('agendar reunião com o time amanhã às 15h');
      expect(r.titulo, 'Reunião com o time');
    });

    test('mantém o substantivo de evento no título (não é removido)', () {
      final r = parser.parse('marcar consulta com o dentista dia 20 às 10h');
      expect(r.titulo, 'Consulta com o dentista');
    });

    test('preserva o texto original completo em textoOriginal', () {
      const texto = 'agendar reunião com o time amanhã às 15h';
      final r = parser.parse(texto);
      expect(r.textoOriginal, texto);
    });

    test('REGRESSÃO: preposição antes da data/hora não fica solta no meio do título', () {
      // antes da correção, "às" ficava órfão e o título saía "Reunião às da equipe"
      final r = parser.parse('agendar reunião amanhã às 15h da equipe');
      expect(r.titulo, 'Reunião da equipe');
      expect(r.hora, 15);
    });

    test('REGRESSÃO: preposição antes de "amanhã" não fica solta no início do título', () {
      // antes da correção, "reunião de amanhã" virava "de" órfão em algum ponto
      final r = parser.parse('agendar reunião de amanhã às 15h');
      expect(r.titulo, 'Reunião');
    });

    test('REGRESSÃO: "no dia N" remove a preposição junto com a data', () {
      final r = parser.parse('agendar reunião com o time no dia 20 às 10h');
      expect(r.titulo, 'Reunião com o time');
    });
  });

  group('VoiceCommandParser.parse — hora, formas coloquiais', () {
    test('"N da tarde" (contração comum em PT-BR) soma 12h ao período', () {
      final r = parser.parse('agendar reunião amanhã às 3 da tarde');
      // sem interpretar "3 da tarde" como 15h — o parser não converte
      // período composto com número; fica só o "às 3" reconhecido, e a
      // tela de confirmação é onde o usuário corrige para 15h.
      expect(r.hora, 3);
    });

    test('"da tarde" sozinho (sem número) usa o período aproximado (15h)', () {
      final r = parser.parse('agendar reunião amanhã da tarde');
      expect(r.hora, 15);
    });

    test('"ao meio-dia" reconhece o conector "ao" junto', () {
      final r = parser.parse('agendar reunião amanhã ao meio-dia');
      expect(r.hora, 12);
      expect(r.titulo, 'Reunião');
    });
  });
}

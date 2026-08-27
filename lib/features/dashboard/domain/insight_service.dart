import 'package:flutter/foundation.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/shared/models/life_area.dart';

/// Uma sugestão curta e acionável pra Hoje — a base do que futuramente vai
/// ocupar o espaço do ícone de chat. Por enquanto é só lógica condicional
/// sobre os dados reais do usuário, sem nenhuma IA por trás. Só o texto:
/// a apresentação (ícone, cor) é decisão de widget, não do domínio.
@immutable
class Insight {
  final String message;

  const Insight({required this.message});
}

/// Gera insights a partir de regras simples sobre tarefas e compromissos.
///
/// Cada regra é um método `_regraX` que devolve um [Insight] só quando se
/// aplica (ou `null` caso contrário). [gerar] roda as regras na ordem de
/// [_regras] — que já é a ordem de prioridade (mais urgente primeiro) — e
/// devolve até 2 insights. Pra adicionar uma regra nova: escreva o método
/// e inclua na lista, na posição de prioridade certa.
class InsightService {
  static const _areasConsideradas = [
    LifeArea.saude,
    LifeArea.trabalho,
    LifeArea.pessoal,
    LifeArea.estudos,
    LifeArea.financeiro,
  ];

  static const _maxInsights = 2;
  static const _minTarefasAtrasadas = 3;
  static const _minCompromissosDiaCheio = 5;
  static const _minAtividadesAreaOcupada = 3;

  List<Insight> gerar({
    required List<TaskModel> tasks,
    required List<EventModel> events,
    DateTime? agora,
  }) {
    final referencia = agora ?? DateTime.now();
    final regras = <Insight? Function()>[
      () => _tarefasAtrasadas(tasks),
      () => _diaCheio(events, referencia),
      () => _desequilibrioAreas(tasks, events, referencia),
    ];

    final gerados = <Insight>[];
    for (final regra in regras) {
      final insight = regra();
      if (insight != null) gerados.add(insight);
      if (gerados.length == _maxInsights) break;
    }
    return gerados;
  }

  /// Regra 1 (mais urgente): 3+ tarefas atrasadas — aponta a área onde
  /// elas mais se concentram.
  Insight? _tarefasAtrasadas(List<TaskModel> tasks) {
    final atrasadas = tasks.where((t) => t.isAtrasada).toList();
    if (atrasadas.length < _minTarefasAtrasadas) return null;

    final porArea = <LifeArea, int>{};
    for (final t in atrasadas) {
      porArea[t.area] = (porArea[t.area] ?? 0) + 1;
    }
    final areaMaisComum = porArea.entries.reduce((a, b) => b.value > a.value ? b : a).key;

    return Insight(message: 'Você tem ${atrasadas.length} tarefas atrasadas em ${areaMaisComum.label}.');
  }

  /// Regra 2: 5+ compromissos hoje.
  Insight? _diaCheio(List<EventModel> events, DateTime agora) {
    final hojeCount = events.where((e) => !e.isDeleted && _mesmoDia(e.startDatetime, agora)).length;
    if (hojeCount < _minCompromissosDiaCheio) return null;

    return Insight(message: 'Seu dia está bem cheio hoje — $hojeCount compromissos.');
  }

  /// Regra 3 (menos urgente): nos últimos 7 dias, uma área não teve
  /// nenhuma tarefa/compromisso enquanto outra teve bastante.
  Insight? _desequilibrioAreas(List<TaskModel> tasks, List<EventModel> events, DateTime agora) {
    final fimJanela = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);
    final inicioJanela = DateTime(agora.year, agora.month, agora.day).subtract(const Duration(days: 6));

    final contagem = <LifeArea, int>{for (final area in _areasConsideradas) area: 0};
    for (final t in tasks) {
      final data = t.dueDate;
      if (data != null && !data.isBefore(inicioJanela) && !data.isAfter(fimJanela)) {
        contagem[t.area] = (contagem[t.area] ?? 0) + 1;
      }
    }
    for (final e in events) {
      if (e.isDeleted || e.lifeArea == null) continue;
      if (!e.startDatetime.isBefore(inicioJanela) && !e.startDatetime.isAfter(fimJanela)) {
        contagem[e.lifeArea!] = (contagem[e.lifeArea!] ?? 0) + 1;
      }
    }

    final ociosas = contagem.entries.where((e) => e.value == 0);
    final temAreaOcupada = contagem.values.any((v) => v >= _minAtividadesAreaOcupada);
    if (ociosas.isEmpty || !temAreaOcupada) return null;

    final area = ociosas.first.key;
    return Insight(message: 'Você não teve nenhuma tarefa ou compromisso de ${area.label} essa semana.');
  }

  bool _mesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

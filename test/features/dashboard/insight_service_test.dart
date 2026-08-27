import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/dashboard/domain/insight_service.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';
import 'package:bussola/shared/models/life_area.dart';

TaskModel _buildTask({
  String id = 'task-1',
  LifeArea area = LifeArea.pessoal,
  TaskStatus status = TaskStatus.pendente,
  DateTime? dueDate,
}) {
  final now = DateTime.now();
  return TaskModel(
    id: id,
    userId: 'user-1',
    title: 'Tarefa',
    area: area,
    status: status,
    dueDate: dueDate,
    createdAt: now,
    updatedAt: now,
  );
}

EventModel _buildEvent({
  String id = 'event-1',
  LifeArea? lifeArea,
  required DateTime startDatetime,
  DateTime? deletedAt,
}) {
  final now = DateTime.now();
  return EventModel(
    id: id,
    calendarId: 'calendar-1',
    userId: 'user-1',
    title: 'Evento',
    startDatetime: startDatetime,
    endDatetime: startDatetime.add(const Duration(hours: 1)),
    timezone: 'America/Sao_Paulo',
    allDay: false,
    lifeArea: lifeArea,
    deletedAt: deletedAt,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final service = InsightService();

  group('InsightService — tarefas atrasadas', () {
    test('3+ tarefas atrasadas gera insight apontando a área mais comum entre elas', () {
      final ontem = DateTime.now().subtract(const Duration(days: 2));
      final tasks = [
        _buildTask(id: '1', area: LifeArea.trabalho, dueDate: ontem),
        _buildTask(id: '2', area: LifeArea.trabalho, dueDate: ontem),
        _buildTask(id: '3', area: LifeArea.saude, dueDate: ontem),
      ];

      final insights = service.gerar(tasks: tasks, events: const []);

      expect(insights, hasLength(1));
      expect(insights.first.message, 'Você tem 3 tarefas atrasadas em Trabalho.');
    });

    test('menos de 3 tarefas atrasadas não gera insight', () {
      final ontem = DateTime.now().subtract(const Duration(days: 2));
      final tasks = [
        _buildTask(id: '1', dueDate: ontem),
        _buildTask(id: '2', dueDate: ontem),
      ];

      expect(service.gerar(tasks: tasks, events: const []), isEmpty);
    });

    test('tarefas atrasadas mas já concluídas não contam', () {
      // Espalhadas em áreas diferentes pra nenhuma bater o limiar de
      // "área ocupada" da regra de desequilíbrio — o teste é só sobre a
      // regra de tarefas atrasadas ignorar tarefas concluídas.
      final ontem = DateTime.now().subtract(const Duration(days: 2));
      final tasks = [
        _buildTask(id: '1', area: LifeArea.trabalho, dueDate: ontem, status: TaskStatus.concluida),
        _buildTask(id: '2', area: LifeArea.saude, dueDate: ontem, status: TaskStatus.concluida),
        _buildTask(id: '3', area: LifeArea.pessoal, dueDate: ontem, status: TaskStatus.concluida),
      ];

      expect(service.gerar(tasks: tasks, events: const []), isEmpty);
    });
  });

  group('InsightService — dia cheio', () {
    test('5+ compromissos hoje gera insight com a contagem', () {
      final hoje = DateTime(2026, 8, 19, 9);
      final events = List.generate(5, (i) => _buildEvent(id: 'e$i', startDatetime: DateTime(2026, 8, 19, 8 + i)));

      final insights = service.gerar(tasks: const [], events: events, agora: hoje);

      expect(insights, hasLength(1));
      expect(insights.first.message, 'Seu dia está bem cheio hoje — 5 compromissos.');
    });

    test('menos de 5 compromissos hoje não gera insight', () {
      final hoje = DateTime(2026, 8, 19, 9);
      final events = List.generate(4, (i) => _buildEvent(id: 'e$i', startDatetime: DateTime(2026, 8, 19, 8 + i)));

      expect(service.gerar(tasks: const [], events: events, agora: hoje), isEmpty);
    });

    test('compromissos excluídos (soft delete) não contam pro total de hoje', () {
      final hoje = DateTime(2026, 8, 19, 9);
      final events = [
        ...List.generate(4, (i) => _buildEvent(id: 'e$i', startDatetime: DateTime(2026, 8, 19, 8 + i))),
        _buildEvent(id: 'excluido', startDatetime: DateTime(2026, 8, 19, 12), deletedAt: DateTime(2026, 8, 18)),
      ];

      expect(service.gerar(tasks: const [], events: events, agora: hoje), isEmpty);
    });

    test('compromissos de outro dia não contam', () {
      final hoje = DateTime(2026, 8, 19, 9);
      final events = List.generate(5, (i) => _buildEvent(id: 'e$i', startDatetime: DateTime(2026, 8, 18, 8 + i)));

      expect(service.gerar(tasks: const [], events: events, agora: hoje), isEmpty);
    });

    test(
      'compromisso perto da virada do dia em UTC ainda conta no dia LOCAL correto',
      () {
        // A hora "na virada" muda de lado conforme o fuso local for atrás
        // ou à frente do UTC — só assim o teste expõe o bug (comparar
        // startDatetime em UTC bruto contra `agora` local) em qualquer
        // máquina com fuso != UTC.
        final offset = DateTime.now().timeZoneOffset;
        final agora = DateTime(2026, 8, 19, 9);
        final horaNaVirada = offset.isNegative
            ? DateTime(2026, 8, 19, 23, 30) // fuso atrás do UTC: fim do dia local já é o dia seguinte em UTC
            : DateTime(2026, 8, 19, 0, 30); // fuso à frente do UTC: início do dia local ainda é o dia anterior em UTC

        // .toUtc() simula como o evento chega vindo do banco (sempre UTC).
        final eventoNaVirada = _buildEvent(id: 'virada', startDatetime: horaNaVirada.toUtc());
        final outros = List.generate(4, (i) => _buildEvent(id: 'e$i', startDatetime: DateTime(2026, 8, 19, 8 + i)));

        final insights = service.gerar(tasks: const [], events: [eventoNaVirada, ...outros], agora: agora);

        expect(insights, hasLength(1));
        expect(insights.first.message, 'Seu dia está bem cheio hoje — 5 compromissos.');
      },
      skip: DateTime.now().timeZoneOffset == Duration.zero
          ? 'Máquina rodando em UTC — a virada de dia local/UTC não é observável aqui.'
          : false,
    );
  });

  group('InsightService — desequilíbrio entre áreas', () {
    // Datas dentro da janela usam `dueDate: hoje` (nunca no passado): uma
    // tarefa com prazo no passado e ainda pendente conta como "atrasada"
    // de verdade (TaskModel.isAtrasada lê o relógio real, não o `agora`
    // injetado aqui), o que disparia a regra 1 antes desta e quebraria o
    // teste. Pra testar exclusão por janela, usa-se `concluida` — conta
    // como atividade da área do mesmo jeito, mas nunca é "atrasada".
    test('área sem nenhuma atividade em 7 dias, com outra área ocupada, gera insight', () {
      final hoje = DateTime.now();
      final tasks = List.generate(3, (i) => _buildTask(id: 'task-$i', area: LifeArea.trabalho, dueDate: hoje));

      final insights = service.gerar(tasks: tasks, events: const [], agora: hoje);

      expect(insights, hasLength(1));
      expect(insights.first.message, 'Você não teve nenhuma tarefa ou compromisso de Saúde essa semana.');
    });

    test('sem nenhuma área ocupada (< 3 atividades), não gera insight mesmo com área ociosa', () {
      final hoje = DateTime.now();
      final tasks = [_buildTask(area: LifeArea.trabalho, dueDate: hoje)];

      expect(service.gerar(tasks: tasks, events: const [], agora: hoje), isEmpty);
    });

    test('todas as áreas com alguma atividade não gera insight', () {
      final hoje = DateTime.now();
      final tasks = [
        for (final area in LifeArea.values) _buildTask(id: 'a-${area.name}', area: area, dueDate: hoje),
        ..._extra3(LifeArea.trabalho, hoje),
      ];

      expect(service.gerar(tasks: tasks, events: const [], agora: hoje), isEmpty);
    });

    test('atividade fora da janela de 7 dias não conta', () {
      final hoje = DateTime.now();
      final foraDaJanela = hoje.subtract(const Duration(days: 20));
      final tasks = List.generate(
        3,
        (i) => _buildTask(id: 'task-$i', area: LifeArea.trabalho, dueDate: foraDaJanela, status: TaskStatus.concluida),
      );

      expect(service.gerar(tasks: tasks, events: const [], agora: hoje), isEmpty);
    });

    test('compromisso com life_area conta como atividade da área', () {
      final hoje = DateTime.now();
      final events = [
        for (int i = 0; i < 3; i++)
          _buildEvent(id: 'e$i', lifeArea: LifeArea.trabalho, startDatetime: DateTime(hoje.year, hoje.month, hoje.day, 9 + i)),
      ];

      final insights = service.gerar(tasks: const [], events: events, agora: hoje);

      expect(insights, hasLength(1));
      expect(insights.first.message, 'Você não teve nenhuma tarefa ou compromisso de Saúde essa semana.');
    });

    test(
      'compromisso perto da virada do dia em UTC ainda conta na janela de 7 dias no fuso LOCAL',
      () {
        final offset = DateTime.now().timeZoneOffset;
        final hoje = DateTime.now();
        final horaNaVirada = offset.isNegative
            ? DateTime(hoje.year, hoje.month, hoje.day, 23, 30)
            : DateTime(hoje.year, hoje.month, hoje.day, 0, 30);

        final events = [
          for (int i = 0; i < 2; i++)
            _buildEvent(id: 'e$i', lifeArea: LifeArea.trabalho, startDatetime: DateTime(hoje.year, hoje.month, hoje.day, 9 + i)),
          // .toUtc() simula como o evento chega vindo do banco (sempre UTC).
          _buildEvent(id: 'virada', lifeArea: LifeArea.trabalho, startDatetime: horaNaVirada.toUtc()),
        ];

        final insights = service.gerar(tasks: const [], events: events, agora: hoje);

        expect(insights, hasLength(1));
        expect(insights.first.message, 'Você não teve nenhuma tarefa ou compromisso de Saúde essa semana.');
      },
      skip: DateTime.now().timeZoneOffset == Duration.zero
          ? 'Máquina rodando em UTC — a virada de dia local/UTC não é observável aqui.'
          : false,
    );
  });

  group('InsightService — prioridade e limite de 2', () {
    test('quando várias regras se aplicam, tarefas atrasadas vem antes de dia cheio', () {
      final hoje = DateTime.now();
      final ontem = hoje.subtract(const Duration(days: 2));
      final tasks = List.generate(3, (i) => _buildTask(id: 'atrasada-$i', area: LifeArea.trabalho, dueDate: ontem));
      final events = List.generate(5, (i) => _buildEvent(id: 'e$i', startDatetime: DateTime(hoje.year, hoje.month, hoje.day, 8 + i)));

      final insights = service.gerar(tasks: tasks, events: events, agora: hoje);

      expect(insights, hasLength(2));
      expect(insights[0].message, contains('tarefas atrasadas'));
      expect(insights[1].message, contains('bem cheio'));
    });

    test('nunca devolve mais de 2 insights mesmo com as 3 regras aplicáveis', () {
      final hoje = DateTime.now();
      final base = DateTime(hoje.year, hoje.month, hoje.day);
      final ontem = hoje.subtract(const Duration(days: 2));

      final tasks = [
        ...List.generate(3, (i) => _buildTask(id: 'atrasada-$i', area: LifeArea.trabalho, dueDate: ontem)),
        ...List.generate(3, (i) => _buildTask(id: 'ocupada-$i', area: LifeArea.trabalho, dueDate: base)),
      ];
      final events = List.generate(5, (i) => _buildEvent(id: 'e$i', startDatetime: base.add(Duration(hours: 8 + i))));

      final insights = service.gerar(tasks: tasks, events: events, agora: hoje);

      expect(insights, hasLength(2));
    });

    test('dia tranquilo (nenhuma regra se aplica) não gera insight nenhum', () {
      final hoje = DateTime.now();
      final tasks = [_buildTask(area: LifeArea.pessoal, dueDate: hoje)];
      final events = [_buildEvent(startDatetime: DateTime(hoje.year, hoje.month, hoje.day, 9))];

      expect(service.gerar(tasks: tasks, events: events, agora: hoje), isEmpty);
    });
  });
}

List<TaskModel> _extra3(LifeArea area, DateTime hoje) =>
    List.generate(3, (i) => _buildTask(id: 'extra-$i', area: area, dueDate: hoje));

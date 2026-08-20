import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';

/// Calcula os dados derivados da tela "Hoje" — só regras sobre as
/// tarefas já carregadas, nada simulado.
class DashboardCalculator {
  /// As 3 tarefas pendentes de maior prioridade — não precisam ser "de
  /// hoje": são as 3 coisas mais importantes para a pessoa olhar primeiro.
  List<TaskModel> prioridades(List<TaskModel> tasks) {
    final pendentes = tasks.where((t) => !t.isConcluida).toList();
    const ordem = {Priority.muitoAlta: 0, Priority.alta: 1, Priority.media: 2, Priority.baixa: 3};
    pendentes.sort((a, b) => ordem[a.priority]!.compareTo(ordem[b.priority]!));
    return pendentes.take(3).toList();
  }

  /// Quantas tarefas foram concluídas hoje. [agora] existe para os
  /// testes fixarem a data de referência sem depender do relógio real.
  int concluidasHoje(List<TaskModel> tasks, {DateTime? agora}) {
    final hoje = agora ?? DateTime.now();
    return tasks.where((t) {
      if (t.completedAt == null) return false;
      final c = t.completedAt!;
      return c.year == hoje.year && c.month == hoje.month && c.day == hoje.day;
    }).length;
  }

  /// Formata a data por extenso, ex: "19 de agosto".
  String formatarData(DateTime data) {
    const meses = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    ];
    return '${data.day} de ${meses[data.month - 1]}';
  }
}

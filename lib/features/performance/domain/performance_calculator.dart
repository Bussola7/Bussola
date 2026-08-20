import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';

/// Calcula os indicadores da tela "Performance" — só regras sobre as
/// tarefas já carregadas, nada simulado.
class PerformanceCalculator {
  /// Quantas tarefas de PRIORIDADE ALTA/MUITO ALTA foram concluídas —
  /// interpretação de "prioridades concluídas" pedida no briefing.
  int prioridadesConcluidas(List<TaskModel> tasks) {
    return tasks.where((t) => t.isConcluida && (t.priority == Priority.alta || t.priority == Priority.muitoAlta)).length;
  }

  /// Tarefas concluídas em cada um dos últimos 7 dias (hoje incluso),
  /// para o gráfico de evolução semanal. [agora] existe para os testes
  /// conseguirem fixar "hoje" sem depender do relógio real — em
  /// produção usa sempre `DateTime.now()`.
  List<int> evolucaoSemanal(List<TaskModel> tasks, {DateTime? agora}) {
    final hoje = agora ?? DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    return List.generate(7, (i) {
      final dia = hojeSemHora.subtract(Duration(days: 6 - i));
      return tasks.where((t) {
        if (t.completedAt == null) return false;
        final c = t.completedAt!;
        return c.year == dia.year && c.month == dia.month && c.day == dia.day;
      }).length;
    });
  }
}

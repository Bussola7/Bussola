/// Modelo simples de um compromisso da timeline do dia.
class TimelineItem {
  final String horario;
  final String titulo;
  const TimelineItem(this.horario, this.titulo);
}

/// Repositório do Dashboard. "Radar", "Próximo compromisso" e a linha do
/// tempo ainda retornam dados simulados — o antigo "Norte do Dia" fake
/// foi removido daqui na Etapa 2.4 e substituído pelo real (ver
/// `NorthOfDayCard` + `DaySummaryService`). Nas próximas etapas, os
/// métodos abaixo também devem passar a buscar dados reais.
class DashboardRepository {
  Future<String> getResumoAgenda() async => 'Agenda equilibrada — você possui 3 horas livres hoje.';

  Future<TimelineItem> getProximoCompromisso() async => const TimelineItem('09:30', 'Reunião Comercial');

  Future<List<TimelineItem>> getTimelineDoDia() async => const [
        TimelineItem('08:00', 'Início do expediente'),
        TimelineItem('09:30', 'Reunião Comercial'),
        TimelineItem('12:00', 'Almoço'),
        TimelineItem('14:00', 'Cliente'),
      ];
}

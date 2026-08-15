/// Formatação de datas em português — usada pelo `CalendarHeader` e pelas
/// 4 visualizações do calendário. Centralizado aqui para não repetir listas
/// de meses/dias da semana em cada widget.
class DateFormatting {
  DateFormatting._();

  static const meses = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];

  static const mesesAbrev = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  static const diasSemana = ['domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado'];

  static const diasSemanaAbrev = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];

  static String mesAno(DateTime data) => '${meses[data.month - 1]} de ${data.year}';

  static String diaMesAno(DateTime data) => '${data.day} de ${meses[data.month - 1]} de ${data.year}';

  static String diaSemanaEData(DateTime data) =>
      '${_capitalize(diasSemana[data.weekday % 7])}, ${data.day} de ${meses[data.month - 1]}';

  /// Rótulo do intervalo de uma semana, ex: "3 – 9 de agosto de 2026"
  /// (ou "27 de jul – 2 de ago de 2026" quando a semana cruza o mês).
  static String intervaloSemana(DateTime inicio, DateTime fim) {
    if (inicio.month == fim.month) {
      return '${inicio.day} – ${fim.day} de ${meses[inicio.month - 1]} de ${fim.year}';
    }
    return '${inicio.day} de ${mesesAbrev[inicio.month - 1]} – ${fim.day} de ${mesesAbrev[fim.month - 1]} de ${fim.year}';
  }

  static bool isMesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime apenasData(DateTime data) => DateTime(data.year, data.month, data.day);

  /// Primeiro dia (domingo) da semana que contém [data].
  static DateTime inicioDaSemana(DateTime data) {
    final diaSemana = data.weekday % 7; // domingo = 0
    return apenasData(data).subtract(Duration(days: diaSemana));
  }

  static String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

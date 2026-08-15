/// Os 4 modos de visualização pedidos para a Agenda.
enum CalendarViewMode { dia, semana, mes, lista }

/// Estado imutável da tela de calendário: qual data está em foco e em
/// qual dos 4 modos ela está sendo exibida. Não guarda nenhum evento —
/// isso é responsabilidade do `EventNotifier` (Etapa 1), que esta tela
/// ainda não consome (entra na Etapa 2.2).
class CalendarUiState {
  final DateTime focusedDate;
  final CalendarViewMode viewMode;

  const CalendarUiState({required this.focusedDate, required this.viewMode});

  factory CalendarUiState.initial() => CalendarUiState(focusedDate: DateTime.now(), viewMode: CalendarViewMode.mes);

  CalendarUiState copyWith({DateTime? focusedDate, CalendarViewMode? viewMode}) {
    return CalendarUiState(
      focusedDate: focusedDate ?? this.focusedDate,
      viewMode: viewMode ?? this.viewMode,
    );
  }
}

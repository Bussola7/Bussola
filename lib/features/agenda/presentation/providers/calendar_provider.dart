import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/features/agenda/data/models/calendar_model.dart';
import 'package:bussola/features/agenda/domain/services/calendar_service.dart';

/// Estado dos calendários do usuário. Nesta etapa só carrega e expõe os
/// dados — nenhuma tela consome este provider ainda (entra na etapa de UI).
class CalendarListState {
  final List<CalendarModel> calendars;
  final bool isLoading;
  final String? errorMessage;

  const CalendarListState({this.calendars = const [], this.isLoading = false, this.errorMessage});

  CalendarListState copyWith({List<CalendarModel>? calendars, bool? isLoading, String? errorMessage}) {
    return CalendarListState(
      calendars: calendars ?? this.calendars,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class CalendarNotifier extends StateNotifier<CalendarListState> {
  final CalendarService _service;

  CalendarNotifier({CalendarService? service})
      : _service = service ?? CalendarService(),
        super(const CalendarListState());

  Future<void> load(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final calendars = await _service.listCalendars(userId);
      state = state.copyWith(calendars: calendars, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Não foi possível carregar os calendários.');
    }
  }
}

final calendarNotifierProvider = StateNotifierProvider<CalendarNotifier, CalendarListState>(
  (ref) => CalendarNotifier(),
);

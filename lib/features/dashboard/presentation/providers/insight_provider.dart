import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/usecases/get_events_usecase.dart';
import 'package:bussola/features/dashboard/domain/insight_service.dart';
import 'package:bussola/features/tasks/presentation/providers/task_provider.dart';

/// Compromissos dos últimos 7 dias (hoje incluso) do usuário [userId] — a
/// janela que o [InsightService] usa pra regra de desequilíbrio entre
/// áreas e pra contar o dia de hoje. Provider próprio (em vez de ler o
/// `eventNotifierProvider`) porque aquele é o período visível da Agenda,
/// que não necessariamente cobre os últimos 7 dias.
final weeklyEventsProvider = FutureProvider.family<List<EventModel>, String>((ref, userId) {
  final agora = DateTime.now();
  final inicio = DateTime(agora.year, agora.month, agora.day).subtract(const Duration(days: 6));
  final fim = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);
  return GetEventsUseCase().execute(userId: userId, start: inicio, end: fim);
});

/// Até 2 insights pra Hoje, combinando as tarefas já carregadas
/// ([taskNotifierProvider]) com os compromissos da semana. Enquanto os
/// compromissos ainda carregam ou falham, some (sem insight) em vez de
/// mostrar um estado de erro — é só uma sugestão, não conteúdo essencial.
final insightsProvider = Provider.family<List<Insight>, String>((ref, userId) {
  final tasks = ref.watch(taskNotifierProvider).tasks;
  final eventsAsync = ref.watch(weeklyEventsProvider(userId));
  final events = eventsAsync.asData?.value ?? const [];
  return InsightService().gerar(tasks: tasks, events: events);
});

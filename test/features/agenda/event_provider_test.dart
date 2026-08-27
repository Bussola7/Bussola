import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/data/models/reminder_model.dart';
import 'package:bussola/features/agenda/domain/entities/event_entity.dart';
import 'package:bussola/features/agenda/domain/services/day_summary_service.dart';
import 'package:bussola/features/agenda/domain/services/schedule_analyzer_service.dart';
import 'package:bussola/features/agenda/domain/usecases/get_day_intelligence_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/set_event_reminders_usecase.dart';
import 'package:bussola/features/agenda/domain/usecases/update_event_usecase.dart';
import 'package:bussola/features/agenda/presentation/providers/day_intelligence_provider.dart';
import 'package:bussola/features/agenda/presentation/providers/event_provider.dart';
import 'package:bussola/features/dashboard/presentation/providers/insight_provider.dart';

EventModel _buildEvent() {
  final now = DateTime.now();
  return EventModel(
    id: 'evt-1',
    calendarId: 'cal-1',
    userId: 'user-1',
    title: 'Consulta',
    startDatetime: DateTime(2026, 8, 19, 9),
    endDatetime: DateTime(2026, 8, 19, 10),
    timezone: 'America/Sao_Paulo',
    allDay: false,
    priority: Priority.media,
    status: EventStatus.confirmado,
    createdAt: now,
    updatedAt: now,
  );
}

DayIntelligence _buildDayIntelligence() {
  return const DayIntelligence(
    analysis: DayScheduleAnalysis(
      eventCount: 0,
      busyDuration: Duration.zero,
      freeDuration: Duration.zero,
      largestFreeInterval: null,
      smallestFreeInterval: null,
      focusBlocks: [],
      completedCount: 0,
      pendingCount: 0,
    ),
    summary: DaySummary(
      eventCount: 0,
      importantMeetingsCount: 0,
      freeDuration: Duration.zero,
      largestFreeInterval: null,
      closingRemark: '',
      nextAction: NextAction(texto: '', rotuloBotao: '', destino: NextActionDestino.agenda),
    ),
    events: [],
  );
}

/// Não fala com o banco: aplica as mudanças da entidade sobre o evento
/// atual e devolve, exatamente como o `UpdateEventUseCase` real faria —
/// só sem passar pelo `EventService`/Supabase.
class _FakeUpdateEventUseCase extends UpdateEventUseCase {
  @override
  Future<EventEntity> execute({required EventModel current, required EventEntity changes, required String updatedByUserId}) async {
    return changes;
  }
}

class _FakeSetEventRemindersUseCase extends SetEventRemindersUseCase {
  @override
  Future<List<ReminderModel>> execute(String eventId, List<ReminderModel> reminders) async => [];
}

void main() {
  test('atualizar um evento invalida dayIntelligenceProvider e weeklyEventsProvider (sem precisar de reload manual)', () async {
    var dayIntelligenceCalls = 0;
    var weeklyEventsCalls = 0;
    const userId = 'user-1';

    final container = ProviderContainer(overrides: [
      dayIntelligenceProvider.overrideWith((ref, uid) async {
        dayIntelligenceCalls++;
        return _buildDayIntelligence();
      }),
      weeklyEventsProvider.overrideWith((ref, uid) async {
        weeklyEventsCalls++;
        return <EventModel>[];
      }),
      eventNotifierProvider.overrideWith(
        (ref) => EventNotifier(
          ref,
          updateEvent: _FakeUpdateEventUseCase(),
          setReminders: _FakeSetEventRemindersUseCase(),
        ),
      ),
    ]);
    addTearDown(container.dispose);

    // Primeira leitura de cada provider — "a Hoje já foi aberta uma vez".
    await container.read(dayIntelligenceProvider(userId).future);
    await container.read(weeklyEventsProvider(userId).future);
    expect(dayIntelligenceCalls, 1);
    expect(weeklyEventsCalls, 1);

    // Edita o evento — simula ir pra Agenda e salvar uma mudança.
    final atual = _buildEvent();
    final mudancas = EventEntity(
      id: atual.id,
      title: 'Consulta remarcada',
      startDatetime: atual.startDatetime,
      endDatetime: atual.endDatetime,
      allDay: false,
    );
    final ok = await container.read(eventNotifierProvider.notifier).updateEvent(
          current: atual,
          changes: mudancas,
          updatedByUserId: userId,
        );
    expect(ok, isTrue);

    // Sem reload manual: ler os providers de novo já deve disparar uma
    // busca nova (invalidados pela edição), não devolver o valor em cache.
    await container.read(dayIntelligenceProvider(userId).future);
    await container.read(weeklyEventsProvider(userId).future);
    expect(dayIntelligenceCalls, 2, reason: 'dayIntelligenceProvider deveria ter sido invalidado após editar o evento');
    expect(weeklyEventsCalls, 2, reason: 'weeklyEventsProvider deveria ter sido invalidado após editar o evento');
  });
}

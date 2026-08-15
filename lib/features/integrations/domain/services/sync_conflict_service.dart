import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/data/models/sync_conflict_model.dart';
import 'package:bussola/features/integrations/data/repositories/integration_repository.dart';
import 'package:bussola/features/integrations/domain/entities/remote_calendar_event.dart';

/// Quem "venceu" um conflito — de onde a versão final deve vir.
enum ConflictWinner { local, remote }

/// Resolve conflitos de sincronização entre o Bússola e um calendário
/// remoto (Google, Outlook, ...).
///
/// Estratégia desta etapa (única implementada): **última alteração vence**
/// — compara `event.updatedAt` (Bússola) com `remoteEvent.updatedAt`
/// (remoto) e usa o mais recente. Todo conflito é registrado em
/// `sync_conflicts`, mesmo quando a decisão é "óbvia" — o registro serve
/// de auditoria e é o que permite, no futuro, trocar de estratégia (ex:
/// "perguntar ao usuário") sem perder o histórico do que já foi decidido
/// automaticamente até aqui.
class SyncConflictService {
  final IntegrationRepository _integrationRepository;

  SyncConflictService({IntegrationRepository? integrationRepository})
      : _integrationRepository = integrationRepository ?? IntegrationRepository();

  /// Evento alterado nos dois lados desde a última sincronização.
  Future<ConflictWinner> resolveUpdatedBothSides({
    required String userId,
    required CalendarProvider provider,
    required EventModel localEvent,
    required RemoteCalendarEvent remoteEvent,
  }) async {
    final vencedor = localEvent.updatedAt.isAfter(remoteEvent.updatedAt) ? ConflictWinner.local : ConflictWinner.remote;

    await _integrationRepository.logConflict(SyncConflictModel(
      id: '',
      userId: userId,
      eventId: localEvent.id,
      googleEventId: remoteEvent.externalId,
      provider: provider,
      conflictType: SyncConflictType.updatedBoth,
      resolutionStrategy: 'last_write_wins',
      resolutionDetails:
          'Local atualizado em ${localEvent.updatedAt.toIso8601String()}, remoto em ${remoteEvent.updatedAt.toIso8601String()}. Venceu: ${vencedor.name}.',
      createdAt: DateTime.now(),
    ));

    return vencedor;
  }

  /// Evento excluído em apenas um dos lados. Nesta estratégia, a exclusão
  /// sempre vence sobre uma edição — não faz sentido "reviver" algo que a
  /// pessoa excluiu deliberadamente em qualquer um dos dois calendários.
  Future<void> logDeletedOneSide({
    required String userId,
    required CalendarProvider provider,
    String? eventId,
    String? googleEventId,
    required String ladoQueExcluiu,
  }) async {
    await _integrationRepository.logConflict(SyncConflictModel(
      id: '',
      userId: userId,
      eventId: eventId,
      googleEventId: googleEventId,
      provider: provider,
      conflictType: SyncConflictType.deletedOneSide,
      resolutionStrategy: 'delete_wins',
      resolutionDetails: 'Excluído no lado: $ladoQueExcluiu. A exclusão foi replicada para o outro lado.',
      createdAt: DateTime.now(),
    ));
  }

  /// Duas edições praticamente simultâneas (mesma janela de tempo) — ainda
  /// assim resolvido por "última alteração vence", mas registrado com um
  /// tipo diferente para facilitar auditoria/depuração depois.
  Future<ConflictWinner> resolveConcurrentUpdate({
    required String userId,
    required CalendarProvider provider,
    required EventModel localEvent,
    required RemoteCalendarEvent remoteEvent,
  }) async {
    final vencedor = localEvent.updatedAt.isAfter(remoteEvent.updatedAt) ? ConflictWinner.local : ConflictWinner.remote;

    await _integrationRepository.logConflict(SyncConflictModel(
      id: '',
      userId: userId,
      eventId: localEvent.id,
      googleEventId: remoteEvent.externalId,
      provider: provider,
      conflictType: SyncConflictType.concurrentUpdate,
      resolutionStrategy: 'last_write_wins',
      resolutionDetails: 'Alterações simultâneas detectadas. Venceu: ${vencedor.name}.',
      createdAt: DateTime.now(),
    ));

    return vencedor;
  }
}

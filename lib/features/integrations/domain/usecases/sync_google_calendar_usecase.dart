import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/data/repositories/google_calendar_repository.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/services/calendar_sync_service.dart';
import 'package:bussola/features/integrations/domain/services/google_auth_service.dart';

/// Caso de uso "Sincronizar Google Calendar". O `CalendarSyncService`
/// é genérico (não assume nenhum provedor sozinho, nem tem valor-padrão
/// escondido para nenhum) — é este Use Case, específico do Google por
/// nome e por natureza, o único lugar que decide "é o Google": informa
/// o `provider` E monta explicitamente as implementações concretas
/// (`GoogleCalendarRepository`, `GoogleAuthService`) ao construir o
/// Service. Uma futura `SyncOutlookCalendarUseCase` faria o mesmo,
/// só trocando as duas implementações e `CalendarProvider.outlook`.
class SyncGoogleCalendarUseCase {
  final CalendarSyncService _syncService;

  SyncGoogleCalendarUseCase({CalendarSyncService? syncService})
      : _syncService = syncService ??
            CalendarSyncService(
              remoteRepository: GoogleCalendarRepository(),
              authService: GoogleAuthService(),
            );

  Future<SyncResult> execute({
    required String userId,
    required String defaultCalendarId,
    SyncDirection direction = SyncDirection.ambos,
  }) {
    return _syncService.syncNow(
      userId: userId,
      defaultCalendarId: defaultCalendarId,
      provider: CalendarProvider.googleCalendar,
      direction: direction,
    );
  }
}

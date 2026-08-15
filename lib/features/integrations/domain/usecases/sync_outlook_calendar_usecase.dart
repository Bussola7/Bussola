import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/data/repositories/outlook_calendar_repository.dart';
import 'package:bussola/features/integrations/domain/entities/sync_types.dart';
import 'package:bussola/features/integrations/domain/services/calendar_sync_service.dart';
import 'package:bussola/features/integrations/domain/services/outlook_auth_service.dart';

/// Caso de uso "Sincronizar Outlook Calendar". Espelha
/// `SyncGoogleCalendarUseCase` peça por peça — o `CalendarSyncService` é
/// genérico (não assume nenhum provedor sozinho, nem tem valor-padrão
/// escondido para nenhum); é este Use Case, específico do Outlook por
/// nome e por natureza, o único lugar que decide "é o Outlook": informa
/// o `provider` E monta explicitamente as implementações concretas
/// (`OutlookCalendarRepository`, `OutlookAuthService`) ao construir o
/// Service.
///
/// Este Use Case NÃO contém nenhuma lógica de sincronização própria —
/// nem retry, nem resolução de conflitos, nem manipulação direta de
/// eventos. Toda a orquestração (as 5 etapas oficiais: baixar, aplicar,
/// excluir, enviar, salvar syncToken) e todo o tratamento de token
/// expirado/reconexão (uma única tentativa de renovação, sem loop) já
/// vivem dentro de `CalendarSyncService.syncNow` — o mesmo código que já
/// atende o Google. `OutlookTokenExpiredException` (erro específico do
/// Outlook, lançado pelo Data Source) já é convertido para
/// `RemoteCalendarAuthExpiredException` (erro de domínio genérico) na
/// fronteira do `OutlookCalendarRepository` (Etapa 1.7) — por isso este
/// Use Case não precisa (e não deve) capturar nada especial aqui: o
/// `CalendarSyncService` já trata esse erro genérico do mesmo jeito para
/// qualquer provedor.
class SyncOutlookCalendarUseCase {
  final CalendarSyncService _syncService;

  SyncOutlookCalendarUseCase({CalendarSyncService? syncService})
      : _syncService = syncService ??
            CalendarSyncService(
              remoteRepository: OutlookCalendarRepository(),
              authService: OutlookAuthService(),
            );

  Future<SyncResult> execute({
    required String userId,
    required String defaultCalendarId,
    SyncDirection direction = SyncDirection.ambos,
  }) {
    return _syncService.syncNow(
      userId: userId,
      defaultCalendarId: defaultCalendarId,
      provider: CalendarProvider.outlook,
      direction: direction,
    );
  }
}

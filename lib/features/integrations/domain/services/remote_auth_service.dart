import 'package:bussola/features/integrations/domain/entities/sync_types.dart';

/// Contrato de autenticação que qualquer provedor de calendário remoto
/// (Google, Outlook, ...) precisa cumprir para o `CalendarSyncService`
/// conseguir sincronizar com ele. Representa só as duas operações que a
/// orquestração de fato usa — nada de Client Secret, tokens de longa
/// duração, Edge Functions ou qualquer outro detalhe de implementação.
///
/// `connect()`/`disconnect()` (login/logout) DELIBERADAMENTE não fazem
/// parte deste contrato: são operações iniciadas pela pessoa através de
/// um Use Case específico do provedor (ex: `ConnectGoogleCalendarUseCase`),
/// nunca pelo `CalendarSyncService` — por isso não precisam ser genéricas
/// aqui.
///
/// O Google já tem a implementação concreta: `GoogleAuthService` (em
/// `domain/services/google_auth_service.dart`) implementa esta interface.
abstract class RemoteAuthService {
  /// Devolve um `access_token` válido para chamar a API do provedor, ou
  /// `null` se não houver conexão ativa.
  Future<String?> getValidAccessToken(String userId);

  /// Tenta renovar o `access_token` — implementação específica de cada
  /// provedor decide como (ex: Google usa um `refresh_token` guardado no
  /// servidor, via Edge Function).
  Future<RefreshResult> refreshAccessToken(String userId);
}

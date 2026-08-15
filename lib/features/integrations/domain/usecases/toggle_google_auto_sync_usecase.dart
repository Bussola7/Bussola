import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/data/repositories/integration_repository.dart';

/// Só guarda a PREFERÊNCIA da pessoa. A execução periódica de verdade em
/// segundo plano não está implementada nesta etapa — ver limitação no
/// relatório (exigiria integração com agendamento nativo do
/// Android/iOS, fora do escopo desta etapa).
///
/// Nomeado explicitamente "Google" (Etapa 1.3.1) — renomeado a partir de
/// `ToggleAutoSyncUseCase` porque o nome genérico anterior escondia que
/// só existe integração com o Google ainda.
class ToggleGoogleAutoSyncUseCase {
  final IntegrationRepository _repository;

  ToggleGoogleAutoSyncUseCase({IntegrationRepository? repository}) : _repository = repository ?? IntegrationRepository();

  Future<void> execute({required String userId, required bool enabled}) {
    return _repository.setAutoSync(userId: userId, provider: CalendarProvider.googleCalendar, enabled: enabled);
  }
}

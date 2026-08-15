import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/data/repositories/integration_repository.dart';

/// Nomeado explicitamente "Google" (Etapa 1.3.1): só funciona com
/// `CalendarProvider.googleCalendar` — renomeado a partir de
/// `GetIntegrationStatusUseCase` porque o nome genérico anterior escondia
/// esse acoplamento (não havia suporte real a outro provedor).
class GetGoogleIntegrationStatusUseCase {
  final IntegrationRepository _repository;

  GetGoogleIntegrationStatusUseCase({IntegrationRepository? repository}) : _repository = repository ?? IntegrationRepository();

  Future<CalendarIntegrationModel?> execute(String userId) {
    return _repository.getIntegration(userId: userId, provider: CalendarProvider.googleCalendar);
  }
}

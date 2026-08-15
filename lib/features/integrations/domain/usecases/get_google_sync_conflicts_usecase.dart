import 'package:bussola/features/integrations/data/models/sync_conflict_model.dart';
import 'package:bussola/features/integrations/data/repositories/integration_repository.dart';

/// Lista os conflitos já registrados pelo `SyncConflictService`. Nesta
/// etapa é só para informar — nenhuma resolução manual ainda (ver
/// limitações no relatório).
///
/// Nomeado explicitamente "Google" (Etapa 1.3.1) — renomeado a partir de
/// `GetSyncConflictsUseCase` porque o nome genérico anterior escondia que
/// só existe integração com o Google ainda.
class GetGoogleSyncConflictsUseCase {
  final IntegrationRepository _repository;

  GetGoogleSyncConflictsUseCase({IntegrationRepository? repository}) : _repository = repository ?? IntegrationRepository();

  Future<List<SyncConflictModel>> execute(String userId) => _repository.listConflicts(userId);
}

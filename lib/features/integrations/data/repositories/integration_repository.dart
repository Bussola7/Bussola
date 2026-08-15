import 'package:bussola/features/integrations/data/datasources/integration_datasource.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/data/models/sync_conflict_model.dart';

class IntegrationRepository {
  final IntegrationDataSource _dataSource;

  IntegrationRepository({IntegrationDataSource? dataSource}) : _dataSource = dataSource ?? IntegrationDataSource();

  Future<CalendarIntegrationModel?> getIntegration({required String userId, required CalendarProvider provider}) async {
    final row = await _dataSource.getIntegration(userId: userId, provider: provider.toDb());
    return row == null ? null : CalendarIntegrationModel.fromJson(row);
  }

  Future<void> updateStatus({
    required String userId,
    required CalendarProvider provider,
    required IntegrationStatus status,
  }) {
    return _dataSource.updateStatus(userId: userId, provider: provider.toDb(), status: status.toDb());
  }

  Future<void> updateSyncState({
    required String userId,
    required CalendarProvider provider,
    String? syncToken,
    required DateTime lastSyncAt,
  }) {
    return _dataSource.updateSyncState(userId: userId, provider: provider.toDb(), syncToken: syncToken, lastSyncAt: lastSyncAt);
  }

  Future<void> disconnect({required String userId, required CalendarProvider provider}) {
    return _dataSource.disconnect(userId: userId, provider: provider.toDb());
  }

  Future<void> setAutoSync({required String userId, required CalendarProvider provider, required bool enabled}) {
    return _dataSource.setAutoSync(userId: userId, provider: provider.toDb(), enabled: enabled);
  }

  Future<SyncConflictModel> logConflict(SyncConflictModel conflict) async {
    final row = await _dataSource.insertConflict(conflict.toInsertJson(userId: conflict.userId));
    return SyncConflictModel.fromJson(row);
  }

  Future<List<SyncConflictModel>> listConflicts(String userId, {CalendarProvider? provider}) async {
    final rows = await _dataSource.listConflicts(userId, provider: provider?.toDb());
    return rows.map(SyncConflictModel.fromJson).toList();
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bussola/core/services/supabase_service.dart';

/// Único ponto que fala com as tabelas `integrations` e `sync_conflicts`.
///
/// Regra de segurança importante: o `select()` abaixo lista as colunas
/// explicitamente e **nunca inclui `refresh_token`** — mesmo que a coluna
/// exista no banco (só a Edge Function `google-oauth-exchange` deveria
/// ler/escrever nela). Nunca trocar isso por `select('*')`.
class IntegrationDataSource {
  SupabaseClient get _client => SupabaseService.client;
  static const _integrationsTable = 'integrations';
  static const _conflictsTable = 'sync_conflicts';

  static const _colunasSeguras =
      'id, user_id, provider, status, token, sync_token, last_sync_at, scopes, auto_sync_enabled, updated_at, created_at';

  Future<Map<String, dynamic>?> getIntegration({required String userId, required String provider}) async {
    return _client
        .from(_integrationsTable)
        .select(_colunasSeguras)
        .eq('user_id', userId)
        .eq('provider', provider)
        .maybeSingle();
  }

  Future<void> updateStatus({required String userId, required String provider, required String status}) async {
    await _client
        .from(_integrationsTable)
        .update({'status': status, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .eq('provider', provider);
  }

  /// Salvo depois de cada sincronização — o `syncToken` é o que permite a
  /// próxima sincronização ser incremental. Esta é uma escrita comum, feita
  /// pelo app autenticado (diferente do `refresh_token`, escrito só pela
  /// Edge Function).
  Future<void> updateSyncState({
    required String userId,
    required String provider,
    String? syncToken,
    required DateTime lastSyncAt,
  }) async {
    await _client.from(_integrationsTable).update({
      if (syncToken != null) 'sync_token': syncToken,
      'last_sync_at': lastSyncAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId).eq('provider', provider);
  }

  Future<void> disconnect({required String userId, required String provider}) async {
    await _client.from(_integrationsTable).update({
      'status': 'desconectado',
      'token': null,
      'sync_token': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId).eq('provider', provider);
  }

  Future<void> setAutoSync({required String userId, required String provider, required bool enabled}) async {
    await _client.from(_integrationsTable).update({
      'auto_sync_enabled': enabled,
    }).eq('user_id', userId).eq('provider', provider);
  }

  Future<Map<String, dynamic>> insertConflict(Map<String, dynamic> data) async {
    final response = await _client.from(_conflictsTable).insert(data).select().single();
    return response;
  }

  /// [provider], quando informado, filtra só os conflitos daquele
  /// provedor — sem isso, a lista viria com Google e Outlook misturados
  /// (achado da auditoria pós-Etapa 1.15; corrigido com a coluna
  /// `provider`, adicionada na migration `0010`).
  Future<List<Map<String, dynamic>>> listConflicts(String userId, {String? provider}) async {
    var query = _client.from(_conflictsTable).select().eq('user_id', userId);
    if (provider != null) query = query.eq('provider', provider);
    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
}

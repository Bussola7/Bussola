import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bussola/core/services/supabase_service.dart';

/// Única classe do módulo Agenda que conversa diretamente com as tabelas
/// `events`, `event_reminders` e `event_participants` no Supabase.
///
/// Soft delete: todo SELECT desta classe já filtra `deleted_at is null` —
/// quem quiser ver eventos excluídos usa [fetchDeleted] especificamente.
class EventDataSource {
  SupabaseClient get _client => SupabaseService.client;
  static const _eventsTable = 'events';
  static const _remindersTable = 'event_reminders';
  static const _participantsTable = 'event_participants';

  // ---- events ----

  Future<List<Map<String, dynamic>>> fetchByPeriod({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _client
        .from(_eventsTable)
        .select()
        .eq('user_id', userId)
        .filter('deleted_at', 'is', null)
        .gte('start_datetime', start.toUtc().toIso8601String())
        .lte('start_datetime', end.toUtc().toIso8601String())
        .order('start_datetime');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchDeleted(String userId) async {
    final response = await _client
        .from(_eventsTable)
        .select()
        .eq('user_id', userId)
        .not('deleted_at', 'is', null)
        .order('deleted_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> fetchById(String id) async {
    return _client.from(_eventsTable).select().eq('id', id).filter('deleted_at', 'is', null).maybeSingle();
  }

  /// Usado pela sincronização com o Google Calendar: encontra o evento
  /// local que já corresponde a um evento do Google (se existir).
  Future<Map<String, dynamic>?> fetchByGoogleEventId({required String userId, required String googleEventId}) async {
    return _client
        .from(_eventsTable)
        .select()
        .eq('user_id', userId)
        .eq('google_event_id', googleEventId)
        .maybeSingle();
  }

  /// Espelha `fetchByGoogleEventId` para o Outlook (Etapa pós-1.15 —
  /// correção da limitação de vínculo multi-provedor). Uma coluna
  /// separada (`outlook_event_id`) — não a mesma `google_event_id` —
  /// porque um evento pode estar vinculado aos dois provedores ao mesmo
  /// tempo, se a pessoa tiver os dois conectados.
  Future<Map<String, dynamic>?> fetchByOutlookEventId({required String userId, required String outlookEventId}) async {
    return _client
        .from(_eventsTable)
        .select()
        .eq('user_id', userId)
        .eq('outlook_event_id', outlookEventId)
        .maybeSingle();
  }

  /// Todos os eventos ativos (não excluídos) de um usuário, sem filtro de
  /// período — usado pela sincronização, que precisa avaliar TODOS os
  /// eventos pendentes de envio ao Google, não só os de um mês específico.
  Future<List<Map<String, dynamic>>> fetchAllActive(String userId) async {
    final response = await _client.from(_eventsTable).select().eq('user_id', userId).filter('deleted_at', 'is', null);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> insertEvent(Map<String, dynamic> data) async {
    final response = await _client.from(_eventsTable).insert(data).select().single();
    return response;
  }

  Future<Map<String, dynamic>> updateEvent(String id, Map<String, dynamic> data) async {
    final response = await _client.from(_eventsTable).update(data).eq('id', id).select().single();
    return response;
  }

  /// Soft delete: marca `deleted_at`, nunca apaga a linha de verdade.
  Future<void> softDeleteEvent(String id, {required String deletedBy}) async {
    await _client.from(_eventsTable).update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': deletedBy,
    }).eq('id', id);
  }

  Future<void> restoreEvent(String id) async {
    await _client.from(_eventsTable).update({'deleted_at': null}).eq('id', id);
  }

  /// Quantos eventos (não excluídos) de um usuário usam esta categoria —
  /// usado para decidir se a categoria pode ser excluída direto ou se
  /// precisa perguntar sobre migração antes.
  Future<int> countByCategory({required String userId, required String categoryId}) async {
    final response = await _client
        .from(_eventsTable)
        .select('id')
        .eq('user_id', userId)
        .eq('category_id', categoryId)
        .filter('deleted_at', 'is', null);
    return List<Map<String, dynamic>>.from(response).length;
  }

  /// Reatribui todos os eventos de uma categoria para outra — usado ao
  /// excluir uma categoria personalizada com eventos vinculados.
  Future<void> reassignCategory({
    required String userId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {
    await _client
        .from(_eventsTable)
        .update({'category_id': toCategoryId})
        .eq('user_id', userId)
        .eq('category_id', fromCategoryId);
  }

  /// Usado depois que uma exclusão local já foi propagada com sucesso ao
  /// Google Calendar: limpa `google_event_id` para a sincronização
  /// seguinte não tentar excluir de novo o mesmo evento no Google
  /// (a chamada seria inofensiva — o Google devolve 410 — mas
  /// desnecessária, e a etapa pede para evitar chamadas repetidas).
  Future<void> clearGoogleEventId(String id) async {
    await _client.from(_eventsTable).update({'google_event_id': null}).eq('id', id);
  }

  /// Espelha `clearGoogleEventId` para o Outlook — mesmo motivo, mesma
  /// garantia contra chamadas repetidas de exclusão.
  Future<void> clearOutlookEventId(String id) async {
    await _client.from(_eventsTable).update({'outlook_event_id': null}).eq('id', id);
  }

  // ---- event_reminders ----

  Future<List<Map<String, dynamic>>> fetchReminders(String eventId) async {
    final response = await _client.from(_remindersTable).select().eq('event_id', eventId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> insertReminder(Map<String, dynamic> data) async {
    final response = await _client.from(_remindersTable).insert(data).select().single();
    return response;
  }

  Future<void> deleteReminder(String id) async {
    await _client.from(_remindersTable).delete().eq('id', id);
  }

  // ---- event_participants ----

  Future<List<Map<String, dynamic>>> fetchParticipants(String eventId) async {
    final response = await _client.from(_participantsTable).select().eq('event_id', eventId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> insertParticipant(Map<String, dynamic> data) async {
    final response = await _client.from(_participantsTable).insert(data).select().single();
    return response;
  }

  Future<void> deleteParticipant(String id) async {
    await _client.from(_participantsTable).delete().eq('id', id);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bussola/core/services/supabase_service.dart';

/// Única classe do módulo Agenda que conversa diretamente com a tabela
/// `categories` no Supabase.
class CategoryDataSource {
  SupabaseClient get _client => SupabaseService.client;
  static const _table = 'categories';

  Future<List<Map<String, dynamic>>> fetchAll(String userId) async {
    final response = await _client.from(_table).select().eq('user_id', userId).order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> insert(Map<String, dynamic> data) async {
    final response = await _client.from(_table).insert(data).select().single();
    return response;
  }

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    final response = await _client.from(_table).update(data).eq('id', id).select().single();
    return response;
  }

  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bussola/core/constants/app_constants.dart';
import 'package:bussola/core/services/supabase_service.dart';

/// Repositório da tabela `integrations`. Nesta sprint ninguém chama estes
/// métodos ainda — eles só existem para a integração com Google Calendar
/// (e outras) ter um lugar pronto para entrar, sem precisar mexer no resto do app.
class IntegrationsRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<void> saveIntegration({
    required String userId,
    required String provider,
    required String status,
    String? token,
  }) {
    return _client.from(AppConstants.tableIntegrations).insert({
      'user_id': userId,
      'provider': provider,
      'status': status,
      'token': token,
    });
  }

  Future<List<Map<String, dynamic>>> getIntegrations(String userId) async {
    final response = await _client.from(AppConstants.tableIntegrations).select().eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bussola/core/constants/app_constants.dart';
import 'package:bussola/core/services/supabase_service.dart';

/// Repositório da tabela `user_preferences`. Guarda o "estilo de
/// produtividade" da pessoa (horários preferidos, modo de planejamento,
/// se a IA está ativada, etc.) — é a base de dados que o módulo de IA
/// vai consumir quando for construído.
///
/// Reservado para uso futuro: nenhuma tela chama esta classe ainda —
/// mesmo status de `lib/features/organizations/`, só que aqui já
/// existe código (o formato dos dados que o módulo de IA vai usar),
/// em vez de só a pasta reservada. Não é código morto por remoção;
/// é preparação para uma feature que ainda não chegou.
class UserPreferencesRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<Map<String, dynamic>?> getPreferences(String userId) async {
    final response = await _client
        .from(AppConstants.tableUserPreferences)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return response;
  }

  Future<void> upsertPreferences({
    required String userId,
    String? productivityStyle,
    String? preferredWorkHours,
    String? planningMode,
    bool aiEnabled = false,
  }) {
    return _client.from(AppConstants.tableUserPreferences).upsert({
      'user_id': userId,
      'productivity_style': productivityStyle,
      'preferred_work_hours': preferredWorkHours,
      'planning_mode': planningMode,
      'ai_enabled': aiEnabled,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}

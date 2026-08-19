import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bussola/core/constants/app_constants.dart';
import 'package:bussola/core/services/supabase_service.dart';
import 'package:bussola/features/goals/data/models/goal_model.dart';

class GoalRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<GoalModel>> getAll(String userId) async {
    final rows = await _client.from(AppConstants.tableGoals).select().eq('user_id', userId).order('due_date');
    return List<Map<String, dynamic>>.from(rows).map(GoalModel.fromJson).toList();
  }

  Future<GoalModel> create(GoalModel goal) async {
    final row = await _client.from(AppConstants.tableGoals).insert(goal.toInsertJson(userId: goal.userId)).select().single();
    return GoalModel.fromJson(row);
  }

  Future<GoalModel> update(GoalModel goal) async {
    final row = await _client.from(AppConstants.tableGoals).update(goal.toUpdateJson()).eq('id', goal.id).select().single();
    return GoalModel.fromJson(row);
  }

  Future<void> delete(String id) async {
    await _client.from(AppConstants.tableGoals).delete().eq('id', id);
  }
}

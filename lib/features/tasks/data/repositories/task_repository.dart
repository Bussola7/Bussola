import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bussola/core/constants/app_constants.dart';
import 'package:bussola/core/services/supabase_service.dart';
import 'package:bussola/features/tasks/data/models/task_model.dart';

/// CRUD de tarefas. Sem soft delete — tarefa excluída é excluída de
/// verdade (diferente de eventos, que têm histórico de sincronização
/// para preservar; tarefas não têm esse motivo).
class TaskRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<TaskModel>> getAll(String userId) async {
    final rows = await _client.from(AppConstants.tableTasks).select().eq('user_id', userId).order('due_date');
    return List<Map<String, dynamic>>.from(rows).map(TaskModel.fromJson).toList();
  }

  Future<TaskModel> create(TaskModel task) async {
    final row = await _client.from(AppConstants.tableTasks).insert(task.toInsertJson(userId: task.userId)).select().single();
    return TaskModel.fromJson(row);
  }

  Future<TaskModel> update(TaskModel task) async {
    final row = await _client.from(AppConstants.tableTasks).update(task.toUpdateJson()).eq('id', task.id).select().single();
    return TaskModel.fromJson(row);
  }

  Future<void> delete(String id) async {
    await _client.from(AppConstants.tableTasks).delete().eq('id', id);
  }
}

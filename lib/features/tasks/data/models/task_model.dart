import 'package:flutter/foundation.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/shared/models/life_area.dart';

enum TaskStatus { pendente, concluida }

extension TaskStatusX on TaskStatus {
  static TaskStatus fromDb(String value) => value == 'concluida' ? TaskStatus.concluida : TaskStatus.pendente;
  String toDb() => this == TaskStatus.concluida ? 'concluida' : 'pendente';
}

/// Representa uma linha da tabela `tasks`.
@immutable
class TaskModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final LifeArea area;
  final Priority priority;
  final TaskStatus status;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.area = LifeArea.pessoal,
    this.priority = Priority.media,
    this.status = TaskStatus.pendente,
    this.dueDate,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isConcluida => status == TaskStatus.concluida;

  /// Atrasada: tem prazo, não está concluída, e o prazo já passou (comparando só a data, sem hora).
  bool get isAtrasada {
    if (dueDate == null || isConcluida) return false;
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    return dueDate!.isBefore(hojeSemHora);
  }

  bool get isHoje {
    if (dueDate == null) return false;
    final hoje = DateTime.now();
    return dueDate!.year == hoje.year && dueDate!.month == hoje.month && dueDate!.day == hoje.day;
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      area: LifeAreaX.fromDb(json['area'] as String? ?? 'pessoal'),
      priority: PriorityX.fromDb(json['priority'] as String? ?? 'media'),
      status: TaskStatusX.fromDb(json['status'] as String? ?? 'pendente'),
      dueDate: json['due_date'] == null ? null : DateTime.parse(json['due_date'] as String),
      completedAt: json['completed_at'] == null ? null : DateTime.parse(json['completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson({required String userId}) => {
        'user_id': userId,
        'title': title,
        'description': description,
        'area': area.toDb(),
        'priority': priority.toDb(),
        'status': status.toDb(),
        'due_date': dueDate == null ? null : '${dueDate!.year.toString().padLeft(4, '0')}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
        'completed_at': completedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toUpdateJson() => toInsertJson(userId: userId);

  TaskModel copyWith({
    String? title,
    String? description,
    LifeArea? area,
    Priority? priority,
    TaskStatus? status,
    DateTime? dueDate,
    DateTime? completedAt,
    bool clearDueDate = false,
    bool clearCompletedAt = false,
  }) {
    return TaskModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      area: area ?? this.area,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

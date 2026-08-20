import 'package:flutter/foundation.dart';
import 'package:bussola/shared/models/life_area.dart';

enum GoalStatus { emAndamento, concluido }

extension GoalStatusX on GoalStatus {
  static GoalStatus fromDb(String value) => value == 'concluido' ? GoalStatus.concluido : GoalStatus.emAndamento;
  String toDb() => this == GoalStatus.concluido ? 'concluido' : 'em_andamento';
}

/// Representa uma linha da tabela `goals`.
@immutable
class GoalModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final LifeArea area;
  final DateTime? dueDate;
  final int progressPercent;
  final GoalStatus status;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GoalModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.area = LifeArea.pessoal,
    this.dueDate,
    this.progressPercent = 0,
    this.status = GoalStatus.emAndamento,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isConcluido => status == GoalStatus.concluido;

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      area: LifeAreaX.fromDb(json['area'] as String? ?? 'pessoal'),
      dueDate: json['due_date'] == null ? null : DateTime.parse(json['due_date'] as String),
      progressPercent: json['progress_percent'] as int? ?? 0,
      status: GoalStatusX.fromDb(json['status'] as String? ?? 'em_andamento'),
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
        'due_date': dueDate == null ? null : '${dueDate!.year.toString().padLeft(4, '0')}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
        'progress_percent': progressPercent,
        'status': status.toDb(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toUpdateJson() => toInsertJson(userId: userId);

  GoalModel copyWith({
    String? title,
    String? description,
    LifeArea? area,
    DateTime? dueDate,
    int? progressPercent,
    GoalStatus? status,
    DateTime? completedAt,
    bool clearDueDate = false,
  }) {
    return GoalModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      area: area ?? this.area,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      progressPercent: progressPercent ?? this.progressPercent,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

import 'package:flutter/foundation.dart';

/// Representa uma linha da tabela `calendars`.
/// Nesta etapa só existe um calendário padrão por usuário, mas o modelo já
/// está pronto para o app suportar múltiplos calendários no futuro.
@immutable
class CalendarModel {
  final String id;
  final String userId;
  final String name;
  final String color;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CalendarModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.color,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CalendarModel.fromJson(Map<String, dynamic> json) {
    return CalendarModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'color': color,
        'is_default': isDefault,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toInsertJson({required String userId}) => {
        'user_id': userId,
        'name': name,
        'color': color,
        'is_default': isDefault,
      };

  CalendarModel copyWith({String? name, String? color, bool? isDefault}) {
    return CalendarModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarModel &&
        other.id == id &&
        other.userId == userId &&
        other.name == name &&
        other.color == color &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode => Object.hash(id, userId, name, color, isDefault);
}

import 'package:flutter/foundation.dart';

/// Representa uma linha da tabela `categories`.
/// As 8 categorias padrão (Trabalho, Família, Saúde, Estudos, Viagens,
/// Compras, Exercícios, Lazer) são criadas automaticamente pelo banco
/// quando o usuário se cadastra (`is_default = true`).
@immutable
class CategoryModel {
  final String id;
  final String userId;
  final String name;
  final String icon;
  final String color;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.color,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
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
        'icon': icon,
        'color': color,
        'is_default': isDefault,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toInsertJson({required String userId}) => {
        'user_id': userId,
        'name': name,
        'icon': icon,
        'color': color,
        'is_default': isDefault,
      };

  CategoryModel copyWith({String? name, String? icon, String? color}) {
    return CategoryModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel &&
        other.id == id &&
        other.userId == userId &&
        other.name == name &&
        other.icon == icon &&
        other.color == color &&
        other.isDefault == isDefault;
  }

  @override
  int get hashCode => Object.hash(id, userId, name, icon, color, isDefault);
}

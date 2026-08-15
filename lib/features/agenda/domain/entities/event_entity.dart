import 'package:flutter/foundation.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';

/// Representa um evento do ponto de vista do domínio/UI. Agora inclui
/// categoria e prioridade (Etapa 2.3) — recorrência, participantes e
/// lembretes continuam fora daqui: lembretes são geridos à parte (lista
/// própria de [ReminderModel], sincronizada depois de salvar o evento).
///
/// `id` é nulo enquanto o evento ainda não foi salvo no banco.
@immutable
class EventEntity {
  final String? id;
  final String title;
  final String? description;
  final DateTime startDatetime;
  final DateTime endDatetime;
  final bool allDay;
  final String? location;
  final String? categoryId;
  final Priority priority;

  const EventEntity({
    this.id,
    required this.title,
    this.description,
    required this.startDatetime,
    required this.endDatetime,
    required this.allDay,
    this.location,
    this.categoryId,
    this.priority = Priority.media,
  });

  Duration get duration => endDatetime.difference(startDatetime);

  EventEntity copyWith({
    String? title,
    String? description,
    DateTime? startDatetime,
    DateTime? endDatetime,
    bool? allDay,
    String? location,
    String? categoryId,
    Priority? priority,
  }) {
    return EventEntity(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDatetime: startDatetime ?? this.startDatetime,
      endDatetime: endDatetime ?? this.endDatetime,
      allDay: allDay ?? this.allDay,
      location: location ?? this.location,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventEntity &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.startDatetime == startDatetime &&
        other.endDatetime == endDatetime &&
        other.allDay == allDay &&
        other.location == location &&
        other.categoryId == categoryId &&
        other.priority == priority;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, description, startDatetime, endDatetime, allDay, location, categoryId, priority);
}

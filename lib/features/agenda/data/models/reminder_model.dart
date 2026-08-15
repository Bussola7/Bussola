import 'package:flutter/foundation.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';

/// Representa uma linha da tabela `event_reminders`.
@immutable
class ReminderModel {
  final String id;
  final String eventId;
  final int minutesBefore;
  final ReminderType type;
  final DateTime createdAt;

  const ReminderModel({
    required this.id,
    required this.eventId,
    required this.minutesBefore,
    required this.type,
    required this.createdAt,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      minutesBefore: json['minutes_before'] as int? ?? 0,
      type: ReminderTypeX.fromDb(json['type'] as String? ?? 'no_horario'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'minutes_before': minutesBefore,
        'type': type.toDb(),
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toInsertJson({required String eventId}) => {
        'event_id': eventId,
        'minutes_before': minutesBefore,
        'type': type.toDb(),
      };

  ReminderModel copyWith({int? minutesBefore, ReminderType? type}) {
    return ReminderModel(
      id: id,
      eventId: eventId,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      type: type ?? this.type,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderModel &&
        other.id == id &&
        other.eventId == eventId &&
        other.minutesBefore == minutesBefore &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, eventId, minutesBefore, type);
}

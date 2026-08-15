import 'package:flutter/foundation.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';

/// Representa uma linha da tabela `event_participants`.
/// Nesta etapa é só a estrutura de dados — convite e confirmação de
/// verdade (envio de email, etc.) entram quando o compartilhamento de
/// agenda for implementado.
@immutable
class ParticipantModel {
  final String id;
  final String eventId;
  final String participantName;
  final String? participantEmail;
  final ParticipantStatus status;
  final DateTime createdAt;

  const ParticipantModel({
    required this.id,
    required this.eventId,
    required this.participantName,
    this.participantEmail,
    required this.status,
    required this.createdAt,
  });

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      participantName: json['participant_name'] as String,
      participantEmail: json['participant_email'] as String?,
      status: ParticipantStatusX.fromDb(json['status'] as String? ?? 'pendente'),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'participant_name': participantName,
        'participant_email': participantEmail,
        'status': status.toDb(),
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toInsertJson({required String eventId}) => {
        'event_id': eventId,
        'participant_name': participantName,
        'participant_email': participantEmail,
        'status': status.toDb(),
      };

  ParticipantModel copyWith({String? participantName, String? participantEmail, ParticipantStatus? status}) {
    return ParticipantModel(
      id: id,
      eventId: eventId,
      participantName: participantName ?? this.participantName,
      participantEmail: participantEmail ?? this.participantEmail,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantModel &&
        other.id == id &&
        other.eventId == eventId &&
        other.participantName == participantName &&
        other.participantEmail == participantEmail &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(id, eventId, participantName, participantEmail, status);
}

import 'package:flutter/foundation.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';

enum SyncConflictType { updatedBoth, deletedOneSide, concurrentUpdate }

extension SyncConflictTypeX on SyncConflictType {
  static SyncConflictType fromDb(String value) {
    switch (value) {
      case 'deleted_one_side':
        return SyncConflictType.deletedOneSide;
      case 'concurrent_update':
        return SyncConflictType.concurrentUpdate;
      case 'updated_both':
      default:
        return SyncConflictType.updatedBoth;
    }
  }

  String toDb() {
    switch (this) {
      case SyncConflictType.updatedBoth:
        return 'updated_both';
      case SyncConflictType.deletedOneSide:
        return 'deleted_one_side';
      case SyncConflictType.concurrentUpdate:
        return 'concurrent_update';
    }
  }
}

/// Representa uma linha da tabela `sync_conflicts` — o registro de UMA
/// decisão tomada pelo `SyncConflictService`. Existe para dar
/// transparência (a pessoa pode ver depois "por que esse evento mudou
/// sozinho") e para permitir, no futuro, trocar a estratégia sem perder o
/// histórico de decisões já tomadas.
///
/// `provider` adicionado na migration `0010` (pós-Etapa 1.15) — antes
/// disso não havia como saber, olhando um conflito já registrado, se ele
/// veio do Google ou do Outlook.
@immutable
class SyncConflictModel {
  final String id;
  final String userId;
  final String? eventId;
  final String? googleEventId;
  final CalendarProvider provider;
  final SyncConflictType conflictType;
  final String resolutionStrategy;
  final String? resolutionDetails;
  final DateTime createdAt;

  const SyncConflictModel({
    required this.id,
    required this.userId,
    this.eventId,
    this.googleEventId,
    required this.provider,
    required this.conflictType,
    required this.resolutionStrategy,
    this.resolutionDetails,
    required this.createdAt,
  });

  factory SyncConflictModel.fromJson(Map<String, dynamic> json) {
    return SyncConflictModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      eventId: json['event_id'] as String?,
      googleEventId: json['google_event_id'] as String?,
      provider: CalendarProviderX.fromDb(json['provider'] as String? ?? 'google_calendar'),
      conflictType: SyncConflictTypeX.fromDb(json['conflict_type'] as String),
      resolutionStrategy: json['resolution_strategy'] as String? ?? 'last_write_wins',
      resolutionDetails: json['resolution_details'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson({required String userId}) => {
        'user_id': userId,
        'event_id': eventId,
        'google_event_id': googleEventId,
        'provider': provider.toDb(),
        'conflict_type': conflictType.toDb(),
        'resolution_strategy': resolutionStrategy,
        'resolution_details': resolutionDetails,
      };
}

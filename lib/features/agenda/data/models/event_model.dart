import 'package:flutter/foundation.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';

/// Representa uma linha da tabela `events`.
///
/// `recurrenceType` guarda apenas o TIPO da recorrência (ex: semanal,
/// diário) — o cálculo das ocorrências futuras é feito por um serviço
/// separado.
///
/// `deletedAt` implementa soft delete: quando preenchido, o evento está
/// "excluído" mas continua no banco (nenhuma consulta do datasource o
/// retorna por padrão). `createdBy`/`updatedBy` preparam o modelo para
/// agendas compartilhadas, onde quem cria/edita pode não ser o dono do evento.
@immutable
class EventModel {
  final String id;
  final String calendarId;
  final String userId;
  final String title;
  final String? description;
  final DateTime startDatetime;
  final DateTime endDatetime;
  final String timezone;
  final bool allDay;
  final String? location;
  final String? categoryId;
  final String? color;
  final Priority priority;
  final EventStatus status;
  final RecurrenceType recurrenceType;
  final String? recurrenceDetail;
  final DateTime? recurrenceUntil;
  final int? recurrenceCount;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventModel({
    required this.id,
    required this.calendarId,
    required this.userId,
    required this.title,
    this.description,
    required this.startDatetime,
    required this.endDatetime,
    required this.timezone,
    required this.allDay,
    this.location,
    this.categoryId,
    this.color,
    this.priority = Priority.media,
    this.status = EventStatus.confirmado,
    this.recurrenceType = RecurrenceType.nunca,
    this.recurrenceDetail,
    this.recurrenceUntil,
    this.recurrenceCount,
    this.createdBy,
    this.updatedBy,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isRecurring => recurrenceType != RecurrenceType.nunca;
  bool get isDeleted => deletedAt != null;

  /// Codifica tipo + detalhe da recorrência num único texto para o campo
  /// `recurrence_rule` do banco. Ex: "semanal" ou "personalizado:SEG,QUI".
  String? get _recurrenceRuleForDb {
    if (recurrenceType == RecurrenceType.nunca) return null;
    if (recurrenceType == RecurrenceType.personalizado && recurrenceDetail != null) {
      return 'personalizado:$recurrenceDetail';
    }
    return recurrenceType.toDb();
  }

  static ({RecurrenceType type, String? detail}) _parseRecurrenceRule(String? raw) {
    if (raw == null || raw.isEmpty) return (type: RecurrenceType.nunca, detail: null);
    if (raw.startsWith('personalizado:')) {
      return (type: RecurrenceType.personalizado, detail: raw.substring('personalizado:'.length));
    }
    return (type: RecurrenceTypeX.fromDb(raw), detail: null);
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final recurrence = _parseRecurrenceRule(json['recurrence_rule'] as String?);
    return EventModel(
      id: json['id'] as String,
      calendarId: json['calendar_id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startDatetime: DateTime.parse(json['start_datetime'] as String),
      endDatetime: DateTime.parse(json['end_datetime'] as String),
      timezone: json['timezone'] as String? ?? 'America/Sao_Paulo',
      allDay: json['all_day'] as bool? ?? false,
      location: json['location'] as String?,
      categoryId: json['category_id'] as String?,
      color: json['color'] as String?,
      priority: PriorityX.fromDb(json['priority'] as String? ?? 'media'),
      status: EventStatusX.fromDb(json['status'] as String? ?? 'confirmado'),
      recurrenceType: recurrence.type,
      recurrenceDetail: recurrence.detail,
      recurrenceUntil: json['recurrence_until'] == null ? null : DateTime.parse(json['recurrence_until'] as String),
      recurrenceCount: json['recurrence_count'] as int?,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      deletedAt: json['deleted_at'] == null ? null : DateTime.parse(json['deleted_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Serialização completa (todas as colunas).
  Map<String, dynamic> toJson() => {
        'id': id,
        'calendar_id': calendarId,
        'user_id': userId,
        'title': title,
        'description': description,
        'start_datetime': startDatetime.toUtc().toIso8601String(),
        'end_datetime': endDatetime.toUtc().toIso8601String(),
        'timezone': timezone,
        'all_day': allDay,
        'location': location,
        'category_id': categoryId,
        'color': color,
        'priority': priority.toDb(),
        'status': status.toDb(),
        'recurrence_rule': _recurrenceRuleForDb,
        'recurrence_until': recurrenceUntil?.toUtc().toIso8601String(),
        'recurrence_count': recurrenceCount,
        'created_by': createdBy,
        'updated_by': updatedBy,
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  /// Campos aceitos pelo Supabase num INSERT (sem id/created_at/updated_at —
  /// quem gera esses é o próprio banco).
  Map<String, dynamic> toInsertJson({required String userId}) => {
        'calendar_id': calendarId,
        'user_id': userId,
        'title': title,
        'description': description,
        'start_datetime': startDatetime.toUtc().toIso8601String(),
        'end_datetime': endDatetime.toUtc().toIso8601String(),
        'timezone': timezone,
        'all_day': allDay,
        'location': location,
        'category_id': categoryId,
        'color': color,
        'priority': priority.toDb(),
        'status': status.toDb(),
        'recurrence_rule': _recurrenceRuleForDb,
        'recurrence_until': recurrenceUntil?.toUtc().toIso8601String(),
        'recurrence_count': recurrenceCount,
        'created_by': createdBy ?? userId,
        'updated_by': updatedBy ?? userId,
      };

  Map<String, dynamic> toUpdateJson({String? updatedByUserId}) => {
        'title': title,
        'description': description,
        'start_datetime': startDatetime.toUtc().toIso8601String(),
        'end_datetime': endDatetime.toUtc().toIso8601String(),
        'timezone': timezone,
        'all_day': allDay,
        'location': location,
        'category_id': categoryId,
        'color': color,
        'priority': priority.toDb(),
        'status': status.toDb(),
        'recurrence_rule': _recurrenceRuleForDb,
        'recurrence_until': recurrenceUntil?.toUtc().toIso8601String(),
        'recurrence_count': recurrenceCount,
        'updated_by': updatedByUserId ?? updatedBy,
      };

  EventModel copyWith({
    String? title,
    String? description,
    DateTime? startDatetime,
    DateTime? endDatetime,
    bool? allDay,
    String? location,
    String? categoryId,
    String? color,
    Priority? priority,
    EventStatus? status,
    RecurrenceType? recurrenceType,
    String? recurrenceDetail,
    DateTime? recurrenceUntil,
    int? recurrenceCount,
    String? updatedBy,
    DateTime? deletedAt,
  }) {
    return EventModel(
      id: id,
      calendarId: calendarId,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      startDatetime: startDatetime ?? this.startDatetime,
      endDatetime: endDatetime ?? this.endDatetime,
      timezone: timezone,
      allDay: allDay ?? this.allDay,
      location: location ?? this.location,
      categoryId: categoryId ?? this.categoryId,
      color: color ?? this.color,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceDetail: recurrenceDetail ?? this.recurrenceDetail,
      recurrenceUntil: recurrenceUntil ?? this.recurrenceUntil,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventModel &&
        other.id == id &&
        other.calendarId == calendarId &&
        other.userId == userId &&
        other.title == title &&
        other.description == description &&
        other.startDatetime == startDatetime &&
        other.endDatetime == endDatetime &&
        other.timezone == timezone &&
        other.allDay == allDay &&
        other.location == location &&
        other.categoryId == categoryId &&
        other.color == color &&
        other.priority == priority &&
        other.status == status &&
        other.recurrenceType == recurrenceType &&
        other.recurrenceDetail == recurrenceDetail &&
        other.recurrenceUntil == recurrenceUntil &&
        other.recurrenceCount == recurrenceCount &&
        other.createdBy == createdBy &&
        other.updatedBy == updatedBy &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        calendarId,
        userId,
        title,
        description,
        startDatetime,
        endDatetime,
        timezone,
        allDay,
        location,
        categoryId,
        color,
        priority,
        status,
        recurrenceType,
        recurrenceDetail,
        recurrenceUntil,
        recurrenceCount,
        createdBy,
        updatedBy,
        deletedAt,
      ]);

  @override
  String toString() => 'EventModel(id: $id, title: $title, start: $startDatetime)';
}

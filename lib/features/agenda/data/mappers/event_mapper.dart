import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/entities/event_entity.dart';

/// Converte entre [EventModel] (camada de dados, com todos os campos de
/// persistência) e [EventEntity] (camada de domínio, só os campos que a
/// UI desta etapa edita). Fica na camada de dados de propósito — é a
/// camada de dados que conhece o model; o domínio não deveria saber que
/// o Supabase existe.
class EventMapper {
  EventMapper._();

  static EventEntity toEntity(EventModel model) {
    return EventEntity(
      id: model.id,
      title: model.title,
      description: model.description,
      startDatetime: model.startDatetime,
      endDatetime: model.endDatetime,
      allDay: model.allDay,
      location: model.location,
      categoryId: model.categoryId,
      priority: model.priority,
    );
  }

  /// Monta um [EventModel] novo (para criação) a partir de uma [EventEntity]
  /// preenchida no editor. Campos que o editor ainda não expõe (recorrência,
  /// participantes...) ficam com os valores padrão do [EventModel].
  static EventModel toNewModel({
    required EventEntity entity,
    required String calendarId,
    required String userId,
  }) {
    final now = DateTime.now();
    return EventModel(
      id: '',
      calendarId: calendarId,
      userId: userId,
      title: entity.title,
      description: entity.description,
      startDatetime: entity.startDatetime,
      endDatetime: entity.endDatetime,
      timezone: 'America/Sao_Paulo',
      allDay: entity.allDay,
      location: entity.location,
      categoryId: entity.categoryId,
      priority: entity.priority,
      createdBy: userId,
      updatedBy: userId,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Aplica as mudanças de uma [EventEntity] editada sobre o [EventModel]
  /// existente — preserva categoria, prioridade, recorrência etc., que o
  /// editor desta etapa não mexe.
  ///
  /// Monta o objeto na mão (em vez de usar `current.copyWith(...)`)
  /// de propósito: o `copyWith` do [EventModel] usa `valor ?? antigo`
  /// internamente, então nunca conseguiria limpar `description`/`location`
  /// quando o usuário apaga o texto no editor — aqui o `null` da entidade
  /// é respeitado de verdade.
  static EventModel applyChanges({required EventModel current, required EventEntity entity}) {
    return EventModel(
      id: current.id,
      calendarId: current.calendarId,
      userId: current.userId,
      title: entity.title,
      description: entity.description,
      startDatetime: entity.startDatetime,
      endDatetime: entity.endDatetime,
      timezone: current.timezone,
      allDay: entity.allDay,
      location: entity.location,
      categoryId: entity.categoryId,
      color: current.color,
      priority: entity.priority,
      status: current.status,
      recurrenceType: current.recurrenceType,
      recurrenceDetail: current.recurrenceDetail,
      createdBy: current.createdBy,
      updatedBy: current.updatedBy,
      deletedAt: current.deletedAt,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );
  }
}

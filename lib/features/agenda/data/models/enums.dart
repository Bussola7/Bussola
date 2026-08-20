/// Prioridade de um evento. O valor salvo no banco é sempre em minúsculo
/// e sem acento (`muito_alta`, `alta`, `media`, `baixa`).
enum Priority { muitoAlta, alta, media, baixa }

extension PriorityX on Priority {
  static Priority fromDb(String value) {
    switch (value) {
      case 'muito_alta':
        return Priority.muitoAlta;
      case 'alta':
        return Priority.alta;
      case 'baixa':
        return Priority.baixa;
      case 'media':
      default:
        return Priority.media;
    }
  }

  String toDb() {
    switch (this) {
      case Priority.muitoAlta:
        return 'muito_alta';
      case Priority.alta:
        return 'alta';
      case Priority.media:
        return 'media';
      case Priority.baixa:
        return 'baixa';
    }
  }
}

/// Status de um evento.
enum EventStatus { confirmado, pendente, cancelado }

extension EventStatusX on EventStatus {
  static EventStatus fromDb(String value) {
    switch (value) {
      case 'pendente':
        return EventStatus.pendente;
      case 'cancelado':
        return EventStatus.cancelado;
      case 'confirmado':
      default:
        return EventStatus.confirmado;
    }
  }

  String toDb() => name;
}

/// Tipo de recorrência de um evento. O cálculo das ocorrências repetidas
/// (usando esta informação) entra na etapa de Recorrência — aqui é só o
/// dado tipado, salvo no campo `recurrence_rule` do banco.
enum RecurrenceType { nunca, diario, semanal, quinzenal, mensal, anual, personalizado }

extension RecurrenceTypeX on RecurrenceType {
  static RecurrenceType fromDb(String? value) {
    switch (value) {
      case 'diario':
        return RecurrenceType.diario;
      case 'semanal':
        return RecurrenceType.semanal;
      case 'quinzenal':
        return RecurrenceType.quinzenal;
      case 'mensal':
        return RecurrenceType.mensal;
      case 'anual':
        return RecurrenceType.anual;
      case 'personalizado':
        return RecurrenceType.personalizado;
      case 'nunca':
      default:
        return RecurrenceType.nunca;
    }
  }

  String toDb() => name;
}

/// Tipos de lembrete suportados.
enum ReminderType { noHorario, min5, min15, min30, hora1, dia1, personalizado }

extension ReminderTypeX on ReminderType {
  static ReminderType fromDb(String value) {
    switch (value) {
      case '5_min':
        return ReminderType.min5;
      case '15_min':
        return ReminderType.min15;
      case '30_min':
        return ReminderType.min30;
      case '1_hora':
        return ReminderType.hora1;
      case '1_dia':
        return ReminderType.dia1;
      case 'personalizado':
        return ReminderType.personalizado;
      case 'no_horario':
      default:
        return ReminderType.noHorario;
    }
  }

  String toDb() {
    switch (this) {
      case ReminderType.noHorario:
        return 'no_horario';
      case ReminderType.min5:
        return '5_min';
      case ReminderType.min15:
        return '15_min';
      case ReminderType.min30:
        return '30_min';
      case ReminderType.hora1:
        return '1_hora';
      case ReminderType.dia1:
        return '1_dia';
      case ReminderType.personalizado:
        return 'personalizado';
    }
  }
}

/// Status de confirmação de um participante.
enum ParticipantStatus { pendente, aceito, recusado }

extension ParticipantStatusX on ParticipantStatus {
  static ParticipantStatus fromDb(String value) {
    switch (value) {
      case 'aceito':
        return ParticipantStatus.aceito;
      case 'recusado':
        return ParticipantStatus.recusado;
      case 'pendente':
      default:
        return ParticipantStatus.pendente;
    }
  }

  String toDb() => name;
}



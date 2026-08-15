import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/integrations/data/models/calendar_integration_model.dart';
import 'package:bussola/features/integrations/domain/entities/remote_calendar_event.dart';

RemoteCalendarEvent _buildEvent({
  required String status,
  RecurrenceType? recurrenceType,
  String? recurrenceDetail,
  DateTime? recurrenceUntil,
  int? recurrenceCount,
}) {
  final now = DateTime.now();
  return RemoteCalendarEvent(
    externalId: 'evt-1',
    title: 'Evento',
    start: now,
    end: now.add(const Duration(hours: 1)),
    allDay: false,
    status: status,
    updatedAt: now,
    recurrenceType: recurrenceType,
    recurrenceDetail: recurrenceDetail,
    recurrenceUntil: recurrenceUntil,
    recurrenceCount: recurrenceCount,
  );
}

EventModel _buildLocalEventComRecorrencia({required RecurrenceType recurrenceType, String? detail}) {
  final now = DateTime.now();
  return EventModel(
    id: 'evt-local-1',
    calendarId: 'cal-1',
    userId: 'user-1',
    title: 'Evento local existente',
    startDatetime: now,
    endDatetime: now.add(const Duration(hours: 1)),
    timezone: 'America/Sao_Paulo',
    allDay: false,
    recurrenceType: recurrenceType,
    recurrenceDetail: detail,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('RemoteCalendarEvent.isCancelled (Etapa 1.4)', () {
    test('true quando status == "cancelled"', () {
      expect(_buildEvent(status: 'cancelled').isCancelled, true);
    });

    test('false para "confirmed"', () {
      expect(_buildEvent(status: 'confirmed').isCancelled, false);
    });

    test('false para qualquer outro valor (ex: "tentative")', () {
      expect(_buildEvent(status: 'tentative').isCancelled, false);
    });
  });

  group('RemoteCalendarEvent.toEventModel — usa isCancelled, não a string crua', () {
    test('evento cancelado vira EventStatus.cancelado', () {
      final model = _buildEvent(status: 'cancelled').toEventModel(userId: 'user-1', calendarId: 'cal-1', provider: CalendarProvider.googleCalendar);
      expect(model.status.name, 'cancelado');
    });

    test('evento confirmado vira EventStatus.confirmado', () {
      final model = _buildEvent(status: 'confirmed').toEventModel(userId: 'user-1', calendarId: 'cal-1', provider: CalendarProvider.googleCalendar);
      expect(model.status.name, 'confirmado');
    });
  });

  group('RemoteCalendarEvent.toEventModel — recorrência (Etapa 1.8)', () {
    test('GOOGLE (recurrenceType null — não informa nada): preserva a recorrência local já existente', () {
      final localExistente = _buildLocalEventComRecorrencia(recurrenceType: RecurrenceType.semanal);
      // Simula o Google: nenhum dos 4 parâmetros de recorrência é passado.
      final remoto = _buildEvent(status: 'confirmed');

      final atualizado = remoto.toEventModel(userId: 'user-1', calendarId: 'cal-1', provider: CalendarProvider.googleCalendar, existingLocal: localExistente);

      expect(atualizado.recurrenceType, RecurrenceType.semanal, reason: 'não pode ter apagado a recorrência local só porque o Google não informou nada');
    });

    test('GOOGLE (evento novo, sem existingLocal, sem recorrência informada): assume "nunca"', () {
      final remoto = _buildEvent(status: 'confirmed');

      final novo = remoto.toEventModel(userId: 'user-1', calendarId: 'cal-1', provider: CalendarProvider.googleCalendar);

      expect(novo.recurrenceType, RecurrenceType.nunca);
    });

    test('OUTLOOK (recurrenceType informado explicitamente): sobrescreve a recorrência local', () {
      final localExistente = _buildLocalEventComRecorrencia(recurrenceType: RecurrenceType.semanal);
      final remoto = _buildEvent(status: 'confirmed', recurrenceType: RecurrenceType.mensal);

      final atualizado = remoto.toEventModel(userId: 'user-1', calendarId: 'cal-1', provider: CalendarProvider.outlook, existingLocal: localExistente);

      expect(atualizado.recurrenceType, RecurrenceType.mensal);
      expect(atualizado.outlookEventId, 'evt-1');
      expect(atualizado.googleEventId, isNull, reason: 'não deveria inventar um vínculo Google que nunca existiu');
    });

    test('OUTLOOK (evento explicitamente sem recorrência — RecurrenceType.nunca): também sobrescreve, não é tratado como "sem informação"', () {
      // Esta é a distinção crucial: `RecurrenceType.nunca` explícito (o
      // Outlook confirma que não é recorrente) é DIFERENTE de `null`
      // (Google não informa nada) — os dois não podem se comportar igual.
      final localExistente = _buildLocalEventComRecorrencia(recurrenceType: RecurrenceType.semanal);
      final remoto = _buildEvent(status: 'confirmed', recurrenceType: RecurrenceType.nunca);

      final atualizado = remoto.toEventModel(userId: 'user-1', calendarId: 'cal-1', provider: CalendarProvider.outlook, existingLocal: localExistente);

      expect(atualizado.recurrenceType, RecurrenceType.nunca);
    });

    test('OUTLOOK (recorrência não suportada, mapeada como personalizado): recurrenceDetail carrega o motivo da perda', () {
      final remoto = _buildEvent(
        status: 'confirmed',
        recurrenceType: RecurrenceType.personalizado,
        recurrenceDetail: 'Padrão semanal com 3 dia(s) da semana não cabe no Bússola.',
      );

      final model = remoto.toEventModel(userId: 'user-1', calendarId: 'cal-1', provider: CalendarProvider.outlook);

      expect(model.recurrenceType, RecurrenceType.personalizado);
      expect(model.recurrenceDetail, contains('não cabe'));
    });

    test('recurrenceUntil/recurrenceCount são repassados quando informados', () {
      final ate = DateTime(2027, 1, 1);
      final remoto = _buildEvent(status: 'confirmed', recurrenceType: RecurrenceType.mensal, recurrenceUntil: ate, recurrenceCount: null);

      final model = remoto.toEventModel(userId: 'user-1', calendarId: 'cal-1', provider: CalendarProvider.outlook);

      expect(model.recurrenceUntil, ate);
    });

    test('sem recorrência local nem remota: EventModel.isRecurring é false', () {
      final remoto = _buildEvent(status: 'confirmed');

      final model = remoto.toEventModel(userId: 'user-1', calendarId: 'cal-1', provider: CalendarProvider.googleCalendar);

      expect(model.isRecurring, false);
    });
  });
}

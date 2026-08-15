import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';

void main() {
  group('EventModel', () {
    final json = {
      'id': 'evt-1',
      'calendar_id': 'cal-1',
      'user_id': 'user-1',
      'title': 'Reunião comercial',
      'description': 'Alinhamento com o cliente',
      'start_datetime': '2026-08-01T12:30:00.000Z',
      'end_datetime': '2026-08-01T13:30:00.000Z',
      'timezone': 'America/Sao_Paulo',
      'all_day': false,
      'location': 'Sala 2',
      'category_id': 'cat-1',
      'color': '#2563EB',
      'priority': 'alta',
      'status': 'confirmado',
      'recurrence_rule': null,
      'created_at': '2026-07-01T10:00:00.000Z',
      'updated_at': '2026-07-01T10:00:00.000Z',
    };

    test('fromJson lê todos os campos corretamente', () {
      final event = EventModel.fromJson(json);

      expect(event.id, 'evt-1');
      expect(event.title, 'Reunião comercial');
      expect(event.priority, Priority.alta);
      expect(event.status, EventStatus.confirmado);
      expect(event.allDay, false);
      expect(event.endDatetime.isAfter(event.startDatetime), true);
    });

    test('toInsertJson envia prioridade e status no formato do banco', () {
      final event = EventModel.fromJson(json);
      final insertJson = event.toInsertJson(userId: 'user-1');

      expect(insertJson['priority'], 'alta');
      expect(insertJson['status'], 'confirmado');
      expect(insertJson['user_id'], 'user-1');
      expect(insertJson.containsKey('id'), false); // id nunca é enviado — quem gera é o banco
    });

    test('copyWith troca só o campo pedido e mantém o resto', () {
      final event = EventModel.fromJson(json);
      final atualizado = event.copyWith(title: 'Novo título');

      expect(atualizado.title, 'Novo título');
      expect(atualizado.id, event.id);
      expect(atualizado.priority, event.priority);
    });

    test('toJson faz o round-trip completo com fromJson', () {
      final event = EventModel.fromJson(json);
      final roundTripped = EventModel.fromJson(event.toJson());

      expect(roundTripped, event);
    });

    test('dois eventos com os mesmos dados são iguais (==)', () {
      final a = EventModel.fromJson(json);
      final b = EventModel.fromJson(json);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('evento sem deleted_at não está excluído; com deleted_at está', () {
      final ativo = EventModel.fromJson(json);
      expect(ativo.isDeleted, false);

      final excluidoJson = {...json, 'deleted_at': '2026-08-02T10:00:00.000Z'};
      final excluido = EventModel.fromJson(excluidoJson);
      expect(excluido.isDeleted, true);
    });
  });
}

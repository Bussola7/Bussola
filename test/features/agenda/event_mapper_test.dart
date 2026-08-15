import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/mappers/event_mapper.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/entities/event_entity.dart';

EventModel _buildModel({String? description, String? location, String? categoryId}) {
  final now = DateTime.now();
  return EventModel(
    id: 'evt-1',
    calendarId: 'cal-1',
    userId: 'user-1',
    title: 'Reunião',
    description: description,
    startDatetime: DateTime(2026, 8, 1, 9, 0),
    endDatetime: DateTime(2026, 8, 1, 10, 0),
    timezone: 'America/Sao_Paulo',
    allDay: false,
    location: location,
    categoryId: categoryId,
    priority: Priority.alta,
    status: EventStatus.confirmado,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('EventMapper.toEntity', () {
    test('copia só os campos que o editor expõe', () {
      final model = _buildModel(description: 'Pauta X', location: 'Sala 2', categoryId: 'cat-trabalho');
      final entity = EventMapper.toEntity(model);

      expect(entity.id, 'evt-1');
      expect(entity.title, 'Reunião');
      expect(entity.description, 'Pauta X');
      expect(entity.location, 'Sala 2');
      expect(entity.categoryId, 'cat-trabalho');
      expect(entity.priority, Priority.alta);
    });
  });

  group('EventMapper.toNewModel', () {
    test('cria um EventModel novo com id vazio e valores padrão', () {
      final entity = EventEntity(
        title: 'Consulta médica',
        startDatetime: DateTime(2026, 8, 2, 14, 0),
        endDatetime: DateTime(2026, 8, 2, 15, 0),
        allDay: false,
        location: 'Clínica Central',
      );

      final model = EventMapper.toNewModel(entity: entity, calendarId: 'cal-1', userId: 'user-1');

      expect(model.id, '');
      expect(model.title, 'Consulta médica');
      expect(model.priority, Priority.media); // valor padrão do EventModel
      expect(model.createdBy, 'user-1');
    });
  });

  group('EventMapper.applyChanges', () {
    test('aplica o que o editor enviar para categoria e prioridade (o editor sempre carrega o valor atual)', () {
      final original = _buildModel(description: 'Antiga', location: 'Sala 1', categoryId: 'cat-trabalho');
      final entity = EventEntity(
        id: original.id,
        title: 'Reunião remarcada',
        description: 'Nova pauta',
        startDatetime: original.startDatetime,
        endDatetime: original.endDatetime,
        allDay: false,
        location: 'Sala 3',
        categoryId: original.categoryId, // editor carregou o valor atual, usuário não mudou
        priority: original.priority, // idem
      );

      final atualizado = EventMapper.applyChanges(current: original, entity: entity);

      expect(atualizado.title, 'Reunião remarcada');
      expect(atualizado.priority, original.priority);
      expect(atualizado.categoryId, original.categoryId);
      expect(atualizado.status, original.status); // status não é editável nesta etapa, sempre vem do original
    });

    test('categoria e prioridade são editáveis: mudar a entidade muda o evento salvo', () {
      final original = _buildModel(categoryId: 'cat-antiga');
      final entity = EventEntity(
        id: original.id,
        title: original.title,
        startDatetime: original.startDatetime,
        endDatetime: original.endDatetime,
        allDay: false,
        categoryId: 'cat-nova',
        priority: Priority.baixa,
      );

      final atualizado = EventMapper.applyChanges(current: original, entity: entity);

      expect(atualizado.categoryId, 'cat-nova');
      expect(atualizado.priority, Priority.baixa);
    });

    test('REGRESSÃO: consegue limpar description e location (não fica preso ao valor antigo)', () {
      final original = _buildModel(description: 'Vai sumir', location: 'Vai sumir também');
      final entity = EventEntity(
        id: original.id,
        title: original.title,
        description: null, // usuário apagou o texto no editor
        startDatetime: original.startDatetime,
        endDatetime: original.endDatetime,
        allDay: false,
        location: null, // usuário apagou o texto no editor
      );

      final atualizado = EventMapper.applyChanges(current: original, entity: entity);

      expect(atualizado.description, isNull);
      expect(atualizado.location, isNull);
    });
  });
}

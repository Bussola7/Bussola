import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/mappers/event_formatting.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';

EventModel _buildEvent({required String start, required String end, bool allDay = false}) {
  return EventModel.fromJson({
    'id': 'evt-1',
    'calendar_id': 'cal-1',
    'user_id': 'user-1',
    'title': 'Evento',
    'start_datetime': start,
    'end_datetime': end,
    'timezone': 'America/Sao_Paulo',
    'all_day': allDay,
    'priority': 'media',
    'status': 'confirmado',
    'created_at': '2026-01-01T00:00:00.000Z',
    'updated_at': '2026-01-01T00:00:00.000Z',
  });
}

void main() {
  group('EventFormatting.horario', () {
    test('converte start/end de UTC pro fuso local antes de formatar', () {
      // REGRESSÃO: antes da correção, a hora era lida direto do UTC salvo
      // (sem .toLocal()), então um evento salvo às 12:10 no Brasil (UTC-3)
      // aparecia como "15:10" — a hora "batia" com o UTC, não com o que a
      // pessoa realmente digitou.
      final startUtc = DateTime.utc(2026, 8, 25, 15, 10);
      final endUtc = DateTime.utc(2026, 8, 25, 16, 10);
      final event = _buildEvent(start: startUtc.toIso8601String(), end: endUtc.toIso8601String());

      final startLocal = startUtc.toLocal();
      final endLocal = endUtc.toLocal();
      String hh(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

      expect(EventFormatting.horario(event), '${hh(startLocal)} – ${hh(endLocal)}');
    });

    test('evento de dia inteiro mostra "Dia inteiro" em vez de horário', () {
      final event = _buildEvent(
        start: '2026-08-25T00:00:00.000Z',
        end: '2026-08-25T23:59:00.000Z',
        allDay: true,
      );

      expect(EventFormatting.horario(event), 'Dia inteiro');
    });
  });

  group('EventFormatting.duracao', () {
    test('calcula a duração em minutos, independente de fuso horário', () {
      final event = _buildEvent(
        start: '2026-08-25T15:10:00.000Z',
        end: '2026-08-25T16:10:00.000Z',
      );

      expect(EventFormatting.duracao(event), '1h');
    });

    test('duração de menos de 1h aparece em minutos', () {
      final event = _buildEvent(
        start: '2026-08-25T15:00:00.000Z',
        end: '2026-08-25T15:30:00.000Z',
      );

      expect(EventFormatting.duracao(event), '30 min');
    });
  });
}

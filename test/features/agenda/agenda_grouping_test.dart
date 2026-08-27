import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/data/models/enums.dart';
import 'package:bussola/features/agenda/data/models/event_model.dart';
import 'package:bussola/features/agenda/domain/agenda_grouping.dart';

EventModel _buildEvent({required String id, required DateTime startDatetime}) {
  final now = DateTime.now();
  return EventModel(
    id: id,
    calendarId: 'cal-1',
    userId: 'user-1',
    title: 'Evento $id',
    startDatetime: startDatetime,
    endDatetime: startDatetime.add(const Duration(hours: 1)),
    timezone: 'America/Sao_Paulo',
    allDay: false,
    priority: Priority.media,
    status: EventStatus.confirmado,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('AgendaGrouping.porDia', () {
    test('agrupa eventos no mesmo fuso pelo dia correto', () {
      final eventos = [
        _buildEvent(id: '1', startDatetime: DateTime(2026, 8, 19, 9)),
        _buildEvent(id: '2', startDatetime: DateTime(2026, 8, 19, 18)),
        _buildEvent(id: '3', startDatetime: DateTime(2026, 8, 20, 8)),
      ];

      final porDia = AgendaGrouping.porDia(eventos);

      expect(porDia.keys, hasLength(2));
      expect(porDia[DateTime(2026, 8, 19)]?.map((e) => e.id), ['1', '2']);
      expect(porDia[DateTime(2026, 8, 20)]?.map((e) => e.id), ['3']);
    });

    test(
      'compromisso perto da virada do dia em UTC é agrupado no dia LOCAL correto, não no dia UTC',
      () {
        // A hora "na virada" muda de lado conforme o fuso local for atrás
        // ou à frente do UTC — só assim o teste expõe o bug (agrupar pelo
        // dia UTC bruto em vez do dia local) em qualquer máquina com fuso
        // != UTC.
        final offset = DateTime.now().timeZoneOffset;
        final horaNaVirada = offset.isNegative
            ? DateTime(2026, 8, 19, 23, 30) // fuso atrás do UTC: fim do dia local já é o dia seguinte em UTC
            : DateTime(2026, 8, 19, 0, 30); // fuso à frente do UTC: início do dia local ainda é o dia anterior em UTC

        // .toUtc() simula como o evento chega vindo do banco (sempre UTC).
        final evento = _buildEvent(id: 'virada', startDatetime: horaNaVirada.toUtc());

        final porDia = AgendaGrouping.porDia([evento]);

        expect(porDia.keys, [DateTime(2026, 8, 19)]);
        expect(porDia[DateTime(2026, 8, 19)]?.single.id, 'virada');
      },
      skip: DateTime.now().timeZoneOffset == Duration.zero
          ? 'Máquina rodando em UTC — a virada de dia local/UTC não é observável aqui.'
          : false,
    );
  });
}

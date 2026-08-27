import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bussola/features/agenda/presentation/providers/day_intelligence_provider.dart';
import 'package:bussola/features/dashboard/presentation/widgets/next_appointment_card.dart';

void main() {
  testWidgets('mostra uma mensagem de erro visível quando dayIntelligenceProvider falha, em vez de ficar em branco', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayIntelligenceProvider.overrideWith((ref, userId) async {
            throw Exception('Falha simulada de rede');
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: NextAppointmentCard(userId: 'user-1'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar seu próximo compromisso.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}

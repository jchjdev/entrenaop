import 'package:entrenaop/features/preparation_goal/presentation/widgets/preparation_goal_review_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'distingue objetivos, marcas del protocolo y referencia ausente',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreparationGoalReviewPanel(
                reviews: [
                  {
                    'name': 'Plancha',
                    'measurement': 'DURATION',
                    'target': 240,
                    'last_protocol_mark': 80,
                    'observed_on': '2026-10-19',
                    'review_reason': 'Las series no estiman tu máximo.',
                  },
                  {
                    'name': 'Circuito',
                    'measurement': 'TIME_FOR_COURSE',
                    'target': 12.5,
                    'last_protocol_mark': null,
                  },
                ],
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Objetivos y controles'));
      await t.pumpAndSettle();
      expect(find.text('Tu objetivo: 4:00 min'), findsOneWidget);
      expect(
        find.text('Última marca del protocolo: 1:20 min · 19/10/2026'),
        findsOneWidget,
      );
      expect(find.text('Tu objetivo: 12,5 s'), findsOneWidget);
      expect(
        find.text('Sin una marca compatible del protocolo.'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('instantáneas anteriores sin revisión no muestran panel vacío', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(home: PreparationGoalReviewPanel(reviews: [])),
    );
    expect(find.text('Objetivos y controles'), findsNothing);
  });
}

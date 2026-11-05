import 'package:entrenaop/features/training_plan/presentation/widgets/training_context_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'disponibilidad y material no comparten estado con el scroll de la página',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              key: const PageStorageKey('training-context-scroll'),
              child: TrainingContextFields(
                availability: const {'1': 45},
                equipment: const {},
                equipmentOptions: const {'cones', 'pull_up_bar'},
                reportsPain: false,
                confirmed: true,
                onAvailability: (_, _) {},
                onEquipment: (_, _) {},
                onPain: (_) {},
                onConfirmed: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final minutes = find.text('Ajustar minutos de un día concreto');
      await tester.ensureVisible(minutes);
      await tester.tap(minutes);
      await tester.pumpAndSettle();
      final equipment = find.text('Añadir o cambiar material');
      await tester.ensureVisible(equipment);
      await tester.tap(equipment);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'conos');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

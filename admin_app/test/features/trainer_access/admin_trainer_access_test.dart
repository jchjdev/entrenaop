import 'package:entrenaop_admin/features/trainer_access/presentation/admin_trainer_access_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../packages/trainer_access/test_support/fake_trainer_repository.dart';

Future<void> press(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'configuración deshabilitada permite consulta y bloquea concesiones',
    (tester) async {
      final repo = FakeTrainerRepository()..managementEnabled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                AdminTrainerAccessCard(repository: repo, userId: 'trainer-a'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar acceso profesional'),
      );
      expect(button.onPressed, isNull);
      expect(repo.changes, isEmpty);
    },
  );
  testWidgets(
    'reintento conserva motivo cupo y revisión sin duplicar la orden',
    (tester) async {
      final repo = FakeTrainerRepository()..saveError = StateError('network');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                AdminTrainerAccessCard(repository: repo, userId: 'trainer-a'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '5');
      await tester.enterText(find.byType(TextField).last, 'Piloto autorizado');
      await press(tester, 'Guardar acceso profesional');
      await press(tester, 'Confirmar');
      expect(repo.changes, hasLength(1));
      repo.saveError = null;
      await press(tester, 'Reintentar el mismo cambio');
      expect(repo.changes, hasLength(2));
      expect(identical(repo.changes[0], repo.changes[1]), isTrue);
      expect(repo.changes.last.limit, 5);
      expect(repo.changes.last.revision, 1);
    },
  );
}

import 'package:entrenaop_admin/features/trainer_access/presentation/admin_trainer_access_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../packages/trainer_access/test_support/fake_trainer_repository.dart';

Future<void> press(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.pumpAndSettle();
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
        find.widgetWithText(FilledButton, 'Guardar acceso regalado'),
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
      await press(tester, 'Guardar acceso regalado');
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

  testWidgets('retirar regalo usa la fuente manual y no el cupo pagado', (
    tester,
  ) async {
    final repo = FakeTrainerRepository()
      ..manualEnabled = false
      ..manualLimit = 1;
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
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '1',
    );
    await tester.enterText(find.byType(TextField).last, 'Retirar concesión');
    await press(tester, 'Guardar acceso regalado');
    expect(find.textContaining('conservará ese acceso'), findsOneWidget);
    await press(tester, 'Confirmar');
    expect(repo.changes.single.enabled, isFalse);
    expect(repo.changes.single.limit, 1);
    expect(repo.changes.single.validUntil, isNull);
    expect(repo.suspensionChanges, isEmpty);
  });

  testWidgets(
    'suspender y reactivar exige motivo incluso sin gestión de regalos',
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
      await press(tester, 'Suspender entrenador');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar suspensión'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Motivo administrativo'),
        'Incumplimiento revisado',
      );
      await press(tester, 'Confirmar suspensión');
      expect(repo.suspensionChanges.single.suspended, isTrue);
      expect(find.text('Acceso profesional suspendido'), findsOneWidget);
      await press(tester, 'Reactivar entrenador');
      await tester.enterText(
        find.widgetWithText(TextField, 'Motivo administrativo'),
        'Incidencia resuelta',
      );
      await press(tester, 'Confirmar reactivación');
      expect(repo.suspensionChanges.last.suspended, isFalse);
      expect(repo.suspensionChanges.last.revision, 2);
      expect(repo.changes, isEmpty);
    },
  );

  testWidgets(
    'reintenta exactamente la suspensión tras una respuesta incierta',
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
      await press(tester, 'Suspender entrenador');
      await tester.enterText(
        find.widgetWithText(TextField, 'Motivo administrativo'),
        'Motivo conservado',
      );
      await press(tester, 'Confirmar suspensión');
      repo.saveError = null;
      await press(tester, 'Reintentar suspensión o reactivación');
      expect(repo.suspensionChanges, hasLength(2));
      expect(
        identical(repo.suspensionChanges.first, repo.suspensionChanges.last),
        isTrue,
      );
    },
  );
}

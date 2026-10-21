import 'dart:async';

import 'package:entrenaop/features/trainers/presentation/my_trainer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_access.dart';

import '../../../packages/trainer_access/test_support/fake_trainer_repository.dart';

Future<void> press(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'vista previa no vincula y editar el código invalida el consentimiento',
    (tester) async {
      final repo = FakeTrainerRepository();
      await tester.pumpWidget(
        MaterialApp(home: MyTrainerPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'a' * 64);
      await press(tester, 'Ver invitación');
      expect(find.text('Preparador A'), findsOneWidget);
      expect(repo.accepts, 0);
      await tester.enterText(find.byType(TextField), 'b' * 64);
      await tester.pump();
      expect(find.text('Aceptar y vincularme'), findsNothing);
      await press(tester, 'Ver invitación');
      await press(tester, 'Aceptar y vincularme');
      expect(repo.accepts, 1);
      expect(find.text('PREPARADOR ACTIVO'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );
  testWidgets('rechaza código incompleto sin consultar el servidor', (
    tester,
  ) async {
    final repo = FakeTrainerRepository();
    await tester.pumpWidget(MaterialApp(home: MyTrainerPage(repository: repo)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abc');
    await press(tester, 'Ver invitación');
    expect(repo.previews, 0);
    expect(
      find.text('Pega el código completo de 64 caracteres.'),
      findsOneWidget,
    );
  });
  testWidgets('terminar necesita confirmación y conserva el vínculo anterior', (
    tester,
  ) async {
    final repo = FakeTrainerRepository()
      ..active = [trainerRelation('Preparador A')];
    await tester.pumpWidget(MaterialApp(home: MyTrainerPage(repository: repo)));
    await tester.pumpAndSettle();
    await press(tester, 'Finalizar vínculo');
    await press(tester, 'Volver');
    expect(repo.ends, 0);
    await press(tester, 'Finalizar vínculo');
    await press(tester, 'Finalizar vínculo');
    expect(repo.ends, 1);
    expect(find.text('Vínculos anteriores'), findsOneWidget);
  });
  testWidgets('respuesta de una identidad anterior no aparece en la nueva', (
    tester,
  ) async {
    final pending = Completer<List<TrainerRelation>>();
    final previous = FakeTrainerRepository()
      ..relationsOverride = () => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        home: MyTrainerPage(key: const ValueKey('a'), repository: previous),
      ),
    );
    final next = FakeTrainerRepository()
      ..active = [trainerRelation('Preparador B')];
    await tester.pumpWidget(
      MaterialApp(
        home: MyTrainerPage(key: const ValueKey('b'), repository: next),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete([trainerRelation('Privado A')]);
    await tester.pumpAndSettle();
    expect(find.text('Preparador B'), findsOneWidget);
    expect(find.text('Privado A'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

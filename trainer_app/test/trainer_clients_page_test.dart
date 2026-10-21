import 'package:entrenaop_trainer/trainer_clients_page.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_access.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';

void main() {
  testWidgets('reintentar una creación incierta conserva identidad y secreto', (
    tester,
  ) async {
    final repo = FakeTrainerRepository()..createError = StateError('network');
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerClientsPage(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Invitar alumno'));
    await tester.tap(find.text('Invitar alumno'));
    await tester.pumpAndSettle();
    expect(repo.drafts, hasLength(1));
    repo.createError = null;
    await tester.ensureVisible(find.text('Reintentar invitación'));
    await tester.tap(find.text('Reintentar invitación'));
    await tester.pumpAndSettle();
    expect(repo.drafts, hasLength(2));
    expect(identical(repo.drafts[0], repo.drafts[1]), isTrue);
    expect(find.text(repo.drafts[0].secret), findsOneWidget);
  });
  testWidgets('cuota completa no permite crear pero conserva consulta', (
    tester,
  ) async {
    final repo = FakeTrainerRepository();
    repo.active = [trainerRelation('Alumno A')];
    // Snapshot autorizado del servidor, independiente del listado paginado.
    repo.current = accessFixture(full: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerClientsPage(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cupo completo'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Invitar alumno'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Alumno A'), findsOneWidget);
  });
  for (final size in [320.0, 1100.0]) {
    testWidgets('clientes y acciones se adaptan a $size con texto grande', (
      tester,
    ) async {
      tester.view.physicalSize = Size(size, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeTrainerRepository()
        ..active = [
          trainerRelation(
            'Alumno con nombre y apellidos especialmente largos para comprobar la lectura',
          ),
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: TrainerClientsPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Finalizar vínculo'), 300);
      expect(tester.takeException(), isNull);
    });
  }
}

TrainerAccess accessFixture({bool full = false}) => TrainerAccess.fromJson({
  'trainer_id': 'trainer-a',
  'enabled': true,
  'effective': true,
  'client_limit': 3,
  'active_clients': full ? 3 : 0,
  'revision': 1,
});

import 'package:entrenaop_trainer/trainer_clients_page.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_access.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';

void main() {
  Future<void> press(WidgetTester tester, String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('la baja conserva la ficha inactiva y sus etapas', (
    tester,
  ) async {
    final repo = FakeTrainerRepository()
      ..active = [trainerRelation('Alumno conservado')];
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerClientsPage(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await press(tester, 'Desactivar servicio');
    await press(tester, 'Desactivar servicio');
    expect(repo.ends, 1);
    expect(repo.active, isEmpty);
    expect(repo.history, hasLength(1));
    await press(tester, 'Inactivos');
    expect(find.text('Alumno conservado'), findsOneWidget);
    expect(find.text('1 etapa de seguimiento'), findsOneWidget);
    await press(tester, 'Historial del vínculo');
    expect(
      find.text('Historial del vínculo · Alumno conservado'),
      findsOneWidget,
    );
    expect(find.text('1/10/2026 → 2/10/2026'), findsOneWidget);
  });

  testWidgets('archivar y recuperar no borra ni reactiva al alumno', (
    tester,
  ) async {
    final repo = FakeTrainerRepository()
      ..history = [trainerRelation('Alumno inactivo', ended: true)];
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: TrainerClientsPage(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await press(tester, 'Inactivos');
    await press(tester, 'Archivar cliente');
    await press(tester, 'Archivar cliente');
    expect(repo.archivedClients, contains('person-a'));
    expect(repo.history, hasLength(1));
    expect(find.text('Alumno inactivo'), findsNothing);
    await press(tester, 'Archivados');
    expect(find.text('Alumno inactivo'), findsOneWidget);
    await press(tester, 'Recuperar cliente');
    await press(tester, 'Recuperar cliente');
    expect(repo.archivedClients, isEmpty);
    expect(repo.active, isEmpty);
    expect(repo.ends, 0);
    await press(tester, 'Inactivos');
    expect(find.text('Alumno inactivo'), findsOneWidget);
  });

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
      await tester.scrollUntilVisible(find.text('Desactivar servicio'), 300);
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

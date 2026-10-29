import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_catalog_trash_page.dart';
import 'package:entrenaop_trainer/trainer_catalog_trash_repository.dart';
import 'package:entrenaop_trainer/trainer_exercise_page.dart';
import 'package:entrenaop_trainer/trainer_exercise_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import 'trainer_exercise_flow_test.dart' show ExerciseFixture, entry;

class _Trash extends TrainerCatalogTrashRepository {
  _Trash(this.ownerKey);
  @override
  final Object ownerKey;
  final operations = <String>[];
  bool fail = true;
  Completer<void>? blocker;
  @override
  Future<void> trash(
    String operationId,
    TrainerCatalogKind kind,
    String id,
  ) async {
    operations.add(operationId);
    await blocker?.future;
    if (fail) throw StateError('Respuesta interrumpida');
  }

  @override
  Future<List<TrainerCatalogTrashEntry>> list(
    TrainerCatalogKind kind, {
    TrainerCatalogTrashEntry? before,
  }) async => [];
  @override
  Future<void> restore(
    String operationId,
    TrainerCatalogTrashEntry entry,
  ) async {}
  @override
  Future<void> purge(
    String operationId,
    TrainerCatalogTrashEntry entry,
  ) async {}
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.text('Mover a papelera'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Mover a papelera'));
  await tester.pump();
}

void main() {
  testWidgets(
    'respuesta perdida conserva UUID y bloquea abandonar antes de confirmar',
    (tester) async {
      final trash = _Trash('owner');
      final exit = WorkflowExitController();
      var refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowExitScope(
              controller: exit,
              child: TrainerCatalogTrashAction(
                repository: trash,
                kind: TrainerCatalogKind.session,
                id: 'session',
                name: 'Fuerza A',
                onTrashed: () async {
                  refreshed++;
                },
              ),
            ),
          ),
        ),
      );
      await _confirm(tester);
      await tester.pumpAndSettle();
      expect(await exit.onExit!(), isFalse);
      expect(refreshed, 0);
      expect(trash.operations, hasLength(1));
      trash.fail = false;
      await tester.tap(find.text('Reintentar envío a papelera'));
      await tester.pumpAndSettle();
      expect(trash.operations, [
        trash.operations.first,
        trash.operations.first,
      ]);
      expect(refreshed, 1);
      expect(await exit.onExit!(), isTrue);
    },
  );

  testWidgets('no refresca otra cuenta tras completar una petición antigua', (
    tester,
  ) async {
    final previous = _Trash('old')
      ..fail = false
      ..blocker = Completer<void>();
    final next = _Trash('new')..fail = false;
    var refreshed = 0;
    Widget page(_Trash repository) => MaterialApp(
      home: Scaffold(
        body: TrainerCatalogTrashAction(
          repository: repository,
          kind: TrainerCatalogKind.exercise,
          id: 'exercise',
          name: 'Dominadas',
          onTrashed: () async {
            refreshed++;
          },
        ),
      ),
    );
    await tester.pumpWidget(page(previous));
    await _confirm(tester);
    expect(previous.operations, hasLength(1));
    await tester.pumpWidget(page(next));
    previous.blocker!.complete();
    await tester.pumpAndSettle();
    expect(next.operations, isEmpty);
    expect(refreshed, 0);
    expect(find.text('Mover a papelera'), findsOneWidget);
  });

  testWidgets(
    'cuota llena permite papelera propia y los oficiales son solo consulta',
    (tester) async {
      final exercises = ExerciseFixture()
        ..limit = 1
        ..rows = [entry('Propio')]
        ..officialRows = [
          TrainerExercise.fromJson({
            'id': 'official',
            'name': 'Oficial',
            'current': true,
            'version': 1,
            'muscle_groups': ['espalda'],
            'equipment': [],
            'difficulty': 'inicial',
            'exercise_type': 'repeticiones',
          }, official: true),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerExercisePage(
            repository: exercises,
            access: FakeTrainerRepository(),
            trashRepository: _Trash('owner'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Propio'));
      await tester.pumpAndSettle();
      expect(find.text('Editar ejercicio'), findsNothing);
      expect(find.byType(TrainerCatalogTrashAction), findsOneWidget);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EntrenaOP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oficial'));
      await tester.pumpAndSettle();
      expect(find.byType(TrainerCatalogTrashAction), findsNothing);
      expect(find.text('Editar ejercicio'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

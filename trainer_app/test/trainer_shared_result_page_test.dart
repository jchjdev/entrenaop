import 'dart:async';

import 'package:entrenaop_trainer/trainer_shared_result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainer_access/trainer_calendar.dart';

Map<String, dynamic> completedResult(String name) => {
  'id': name,
  'template_id': 'template',
  'template_name': name,
  'template_version': 1,
  'status': 'completed',
  'started_at': '2026-11-01T10:00:00Z',
  'final_rpe': null,
  'workout_amrap_results': [],
  'workout_execution_sets': [
    for (var i = 0; i < 3; i++)
      {
        'id': 'set-$i',
        'block_order': 0,
        'block_name': 'Fuerza',
        'block_format': 'straight_sets',
        'item_order': 0,
        'exercise_id': 'bench',
        'exercise_name': 'Press banca compartido',
        'set_order': i,
        'status': 'completed',
        'target_reps': 5,
        'actual_reps': 5,
        'actual_load_kg': 20,
      },
  ],
};

class ResultFixture implements TrainerSharedWorkoutResultRepository {
  ResultFixture(this.name);
  final String name;
  bool denied = false;
  Completer<Map<String, dynamic>?>? pending;
  final requests = <(String, String)>[];
  @override
  Future<Map<String, dynamic>?> result(
    String clientId,
    String scheduledId,
  ) async {
    requests.add((clientId, scheduledId));
    if (pending != null) return pending!.future;
    if (denied) throw StateError('Permiso retirado');
    return completedResult(name);
  }
}

void main() {
  testWidgets(
    'el titular consulta sus datos sin presentarlos como consentimiento a terceros',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerSharedResultPage(
            repository: ResultFixture('Sesión propia'),
            clientId: 'self',
            scheduledId: 'scheduled',
            isSelf: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tu resultado'), findsOneWidget);
      expect(find.text('Sesión propia'), findsOneWidget);
      expect(find.textContaining('Tus resultados deportivos'), findsOneWidget);
      expect(find.textContaining('autorizados por el alumno'), findsNothing);
    },
  );
  testWidgets(
    'muestra resultado deportivo plegable y retira datos al revocar',
    (tester) async {
      final repository = ResultFixture('Sesión autorizada');
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerSharedResultPage(
            repository: repository,
            clientId: 'student',
            scheduledId: 'scheduled',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.requests.single, ('student', 'scheduled'));
      expect(find.text('Sesión autorizada'), findsOneWidget);
      expect(find.text('RPE final'), findsNothing);
      expect(find.textContaining('Solo lectura'), findsOneWidget);
      repository.denied = true;
      await tester.tap(find.byTooltip('Actualizar resultado'));
      await tester.pumpAndSettle();
      expect(find.text('Sesión autorizada'), findsNothing);
      expect(find.textContaining('No se puede consultar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'una respuesta antigua no aparece tras cambiar de alumno o cuenta',
    (tester) async {
      final first = ResultFixture('Privado anterior')..pending = Completer();
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerSharedResultPage(
            repository: first,
            clientId: 'first',
            scheduledId: 'old',
          ),
        ),
      );
      await tester.pump();
      final second = ResultFixture('Resultado actual');
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerSharedResultPage(
            repository: second,
            clientId: 'second',
            scheduledId: 'new',
          ),
        ),
      );
      await tester.pumpAndSettle();
      first.pending!.complete(completedResult('Privado anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Resultado actual'), findsOneWidget);
      expect(find.text('Privado anterior'), findsNothing);
      expect(second.requests.single, ('second', 'new'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('resultado compartido cabe en 320 con texto ampliado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: TrainerSharedResultPage(
          repository: ResultFixture('Fuerza compartida'),
          clientId: 'student',
          scheduledId: 'scheduled',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fuerza compartida'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

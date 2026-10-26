import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_session_set_draft.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_state.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_session_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('abre la serie pendiente lejana con texto a $scale', (
      tester,
    ) async {
      final execution = _execution();
      WorkoutExecutionSet? edited;
      await _mount(
        tester,
        execution,
        initialSetId: 'set-43',
        scale: scale,
        onEdit: (set) => edited = set,
      );
      final row = find.ancestor(
        of: find.text('Serie 2'),
        matching: find.byType(ListTile),
      );
      expect(row.hitTestable(), findsOneWidget);
      await tester.tap(row.hitTestable());
      expect(edited?.id, 'set-43');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mantiene la consulta al actualizar datos y enfoca al reabrir', (
    tester,
  ) async {
    final execution = _execution();
    await _mount(tester, execution, initialSetId: 'set-43');
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, greaterThan(0));
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();
    await _mount(tester, execution, initialSetId: 'set-45');
    expect(scrollable.position.pixels, 0);
    await tester.pumpWidget(const SizedBox());
    await _mount(tester, execution, initialSetId: 'set-45');
    expect(find.textContaining('Por realizar').hitTestable(), findsWidgets);
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin pendientes enfoca el bloque AMRAP actual', (tester) async {
    final execution = _execution(amrap: true);
    await _mount(tester, execution, initialSetId: execution.currentSet!.id);
    expect(find.text('Bloque 15 · AMRAP').hitTestable(), findsOneWidget);
    expect(find.text('Ejercicio 15').hitTestable(), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('elige la última terminada pendiente, excluyendo confirmadas y sin terminar', () {
    final execution = _execution();
    final state = ActiveWorkoutState(
      execution: execution,
      drafts: {
        'set-1': _draft(1, minute: 4),
        'set-40': _draft(40, minute: 2),
        'set-43': _draft(43, minute: 3),
        'set-44': _draft(44, minute: 5, confirmed: true),
        'set-45': _draft(45, minute: 6),
        'set-46': const WorkoutSessionSetDraft(
          result: WorkoutSetResultInput(resultId: 'set-46'),
        ),
      },
    );
    expect(state.latestUnconfirmedSet?.id, 'set-1');
    expect(
      ActiveWorkoutState(execution: execution).latestUnconfirmedSet,
      isNull,
    );
  });
}

WorkoutSessionSetDraft _draft(
  int i, {
  required int minute,
  bool confirmed = false,
}) => WorkoutSessionSetDraft(
  result: WorkoutSetResultInput(resultId: 'set-$i'),
  endedAt: DateTime.utc(2026, 10, 26, 10, minute),
  confirmed: confirmed,
);

WorkoutExecution _execution({bool amrap = false}) => WorkoutExecution(
  id: 'session',
  templateId: 'template',
  templateName: 'Sesión larga',
  templateVersion: 1,
  status: WorkoutExecutionStatus.inProgress,
  startedAt: DateTime.utc(2026, 10, 26),
  sets: [
    for (var i = 0; i < 48; i++)
      WorkoutExecutionSet(
        id: 'set-$i',
        blockOrder: i ~/ 3,
        blockName: 'Bloque ${i ~/ 3}',
        blockFormat: amrap && i >= 45
            ? WorkoutBlockFormat.amrap
            : WorkoutBlockFormat.straightSets,
        itemOrder: 0,
        exerciseId: 'exercise-${i ~/ 3}',
        exerciseName: 'Ejercicio ${i ~/ 3}',
        setOrder: i % 3,
        targetReps: 8,
        restAfterSeconds: 60,
        status: i < 45 ? WorkoutSetStatus.completed : WorkoutSetStatus.pending,
      ),
  ],
);

Future<void> _mount(
  WidgetTester tester,
  WorkoutExecution execution, {
  required String initialSetId,
  double scale = 1,
  ValueChanged<WorkoutExecutionSet>? onEdit,
}) async {
  tester.view.physicalSize = const Size(390, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: EntrenaTheme.dark,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: SizedBox(
            height: 380,
            child: WorkoutSessionRecords(
              execution: execution,
              drafts: const {},
              initialSetId: initialSetId,
              onEdit: onEdit ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

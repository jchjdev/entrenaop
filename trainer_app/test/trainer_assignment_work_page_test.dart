import 'package:entrenaop_trainer/trainer_assignment_work_page.dart';
import 'package:entrenaop_trainer/trainer_session_work_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

import 'trainer_operations_flow_test.dart' show OperationsFixture;
import 'trainer_session_work_editor_test.dart'
    show SessionWorkFixture, rawState, workId;
import 'trainer_workout_flow_test.dart' show WorkoutFixture;

void main() {
  testWidgets('recupera adaptación con origen previo sin cargar receta nueva', (
    tester,
  ) async {
    final origin = trainerSessionWorkOrigin(
      baseId: 'versión-anterior',
      assignmentId: 'assignment',
      planningRevision: 2,
    );
    final works = SessionWorkFixture()
      ..stored = WorkoutEditorWork(
        id: workId,
        origin: origin,
        state: rawState(),
        revision: 4,
      );
    await tester.pumpWidget(
      MaterialApp(
        home: TrainerAssignmentWorkPage(
          operations: OperationsFixture(),
          workouts: WorkoutFixture(),
          assignmentId: 'assignment',
          workId: workId,
          repository: (_) => works,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutEditorPage), findsOneWidget);
    expect(find.text('Adaptación de Alumno'), findsOneWidget);
    expect(find.text('Sesión recuperable'), findsOneWidget);
    final recovered = tester.widget<TrainerSessionWorkEditor>(
      find.byType(TrainerSessionWorkEditor),
    );
    expect(recovered.initialOrigin, origin);
    expect(works.saved, isEmpty);
  });

  testWidgets('un fallo de lectura no ofrece un formulario vacío', (
    tester,
  ) async {
    final works = SessionWorkFixture()..failLoad = true;
    await tester.pumpWidget(
      MaterialApp(
        home: TrainerAssignmentWorkPage(
          operations: OperationsFixture(),
          workouts: WorkoutFixture(),
          assignmentId: 'assignment',
          workId: workId,
          repository: (_) => works,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutEditorPage), findsNothing);
    expect(find.text('Reintentar recuperación'), findsOneWidget);
    expect(works.saved, isEmpty);
  });
}

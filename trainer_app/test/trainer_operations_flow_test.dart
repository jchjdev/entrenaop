import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_operations_pages.dart';
import 'package:entrenaop_trainer/trainer_operations_repository.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:entrenaop_trainer/trainer_workout_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';

import 'trainer_workout_flow_test.dart'
    show WorkoutFixture, privateRecipe, press;

class OperationsFixture extends TrainerOperationsRepository {
  bool fail = true;
  final changed = <(String, int, DateTime)>[];
  final recipes = <CreatePersonalWorkoutInput?>[];
  final marked = <(String, String?)>[];
  final detail = TrainerAssignmentContext.fromJson({
    'id': 'assignment',
    'template_id': 'template',
    'template_name': 'Fuerza privada',
    'template_version': 1,
    'scheduled_date': '2026-10-21',
    'created_at': '2026-10-21T10:00:00Z',
    'status': 'planned',
    'planning_revision': 3,
    'result_revision': 8,
    'client_id': 'client',
    'client_name': 'Alumno',
    'relation_id': 'relation',
  });
  @override
  Future<TrainerAssignmentContext> assignment(String id) async => detail;
  final fingerprints = <String>[];
  int previews = 0;
  @override
  Future<TrainerAssignmentChangePreview> previewChange({
    required TrainerAssignment assignment,
    required DateTime date,
    String? note,
    CreatePersonalWorkoutInput? recipe,
  }) async {
    previews++;
    return TrainerAssignmentChangePreview(
      fingerprint: 'preview-$previews',
      hasDateCoincidence: date.day == 22,
    );
  }

  @override
  Future<void> change({
    required String operationId,
    required TrainerAssignment assignment,
    required DateTime date,
    required String fingerprint,
    String? note,
    CreatePersonalWorkoutInput? recipe,
  }) async {
    fingerprints.add(fingerprint);
    changed.add((operationId, assignment.revision, date));
    recipes.add(recipe);
    if (fail) throw StateError('Respuesta perdida');
  }

  @override
  Future<List<TrainerReviewItem>> reviews({TrainerReviewItem? before}) async =>
      [];
  @override
  Future<void> markReviewed({
    required String operationId,
    required String assignmentId,
    required int resultRevision,
    String? privateNote,
  }) async {
    marked.add((operationId, privateNote));
    if (fail) throw StateError('Respuesta perdida');
  }
}

void main() {
  testWidgets(
    'resultado se recarga al actualizar y después de confirmar revisión',
    (tester) async {
      final operations = OperationsFixture()..fail = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerWorkoutResultPage(
            repository: WorkoutFixture(),
            assignmentId: 'assignment',
            operations: operations,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(find.text('Resultado del alumno'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await press(tester, 'Marcar revisado');
      await press(tester, 'Marcar revisado');
      expect(operations.marked, hasLength(1));
      expect(find.text('Marcar resultado revisado'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'adaptar conserva envío incierto y receta original sin revisar biblioteca',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final operations = OperationsFixture();
      final workouts = WorkoutFixture();
      final exits = WorkflowExitRegistry();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/adapt'),
                child: const Text('Adaptar'),
              ),
            ),
          ),
          GoRoute(
            path: '/adapt',
            onExit: (_, state) => exits.requestExit(state.pageKey),
            builder: (_, state) => WorkflowExitScope(
              controller: exits.controller(state.pageKey),
              child: TrainerAssignmentAdaptationPage(
                operations: operations,
                workouts: workouts,
                assignmentId: 'assignment',
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await press(tester, 'Adaptar');
      expect(find.byType(WorkoutEditorPage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Guardar adaptación individual'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await press(tester, 'Guardar adaptación individual');
      expect(operations.changed, hasLength(1));
      expect(workouts.saved, isEmpty);
      expect(find.byType(WorkoutEditorPage), findsOneWidget);
      expect(find.text('Reintentar la misma adaptación'), findsOneWidget);
      operations.fail = false;
      await press(tester, 'Reintentar la misma adaptación');
      expect(operations.changed, hasLength(2));
      expect(operations.changed[0], operations.changed[1]);
      expect(identical(operations.recipes[0], operations.recipes[1]), isTrue);
      expect(operations.previews, 1);
      expect(operations.fingerprints, ['preview-1', 'preview-1']);
      expect(operations.recipes.first!.name, privateRecipe.name);
      expect(workouts.saved, isEmpty);
      expect(find.byType(TrainerAssignmentAdaptationPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'mover avisa de coincidencia y reintenta revisión original sin mutar DTO',
    (tester) async {
      final repo = OperationsFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showTrainerMoveDialog(
                  context,
                  repo,
                  repo.detail.assignment,
                  DateTime(2026, 10, 22),
                ),
                child: const Text('Mover'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mover'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ya hay otra sesión'), findsOneWidget);
      await tester.tap(find.text('Confirmar cambio'));
      await tester.pumpAndSettle();
      expect(repo.changed, hasLength(1));
      expect(repo.detail.assignment.date, DateTime(2026, 10, 21));
      repo.fail = false;
      await tester.tap(find.text('Reintentar el mismo cambio'));
      await tester.pumpAndSettle();
      expect(repo.changed[0], repo.changed[1]);
      expect(repo.changed, hasLength(2));
      expect(repo.previews, 1);
      expect(repo.fingerprints, ['preview-1', 'preview-1']);
      expect(find.text('Mover pauta pendiente'), findsNothing);
    },
  );

  testWidgets('nota de revisión privada se congela hasta confirmar el recibo', (
    tester,
  ) async {
    final repo = OperationsFixture();
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showTrainerReviewDialog(context, repo, 'assignment', 8, null),
              child: const Text('Revisar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('El alumno no recibe este texto'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField),
      'Revisar técnica en la próxima cita',
    );
    await tester.tap(find.text('Marcar revisado'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    repo.fail = false;
    await tester.tap(find.text('Reintentar la revisión'));
    await tester.pumpAndSettle();
    expect(repo.marked, hasLength(2));
    expect(repo.marked[0], repo.marked[1]);
    expect(repo.marked.first.$2, 'Revisar técnica en la próxima cita');
    expect(tester.takeException(), isNull);
  });
}

import 'dart:async';

import 'package:entrenaop_trainer/trainer_workout_pages.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:entrenaop_trainer/trainer_workout_result.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_template_content.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';

const privateRecipe = WorkoutTemplate(
  id: 'template',
  name: 'Fuerza para pruebas físicas',
  description: 'Trabajo privado de ensayo',
  estimatedDurationMinutes: 30,
  version: 3,
  blocks: [
    WorkoutBlock(
      id: 'block',
      name: 'Bloque principal',
      format: WorkoutBlockFormat.straightSets,
      rounds: 1,
      restAfterSeconds: 0,
      items: [
        WorkoutItem(
          id: 'item',
          exerciseId: 'exercise',
          exerciseName: 'Dominadas',
          sets: [
            WorkoutSet(
              id: 'set',
              order: 0,
              targetReps: 10,
              targetLoadKg: 5,
              targetRir: 2,
              restAfterSeconds: 90,
            ),
          ],
        ),
      ],
    ),
  ],
);

class WorkoutFixture extends TrainerWorkoutRepository {
  bool failAssign = false;
  bool failWorkouts = false;
  int libraryReads = 0;
  List<TrainerWorkout>? availableWorkouts;
  final assigned =
      <
        ({
          String id,
          String relation,
          String template,
          DateTime date,
          String? note,
        })
      >[];
  final saved =
      <({String id, CreatePersonalWorkoutInput input, String? previous})>[];
  Completer<String>? pendingSave;
  final entry = TrainerWorkout.fromJson({
    'id': 'template',
    'name': privateRecipe.name,
    'version': 3,
    'created_at': '2026-10-21T10:00:00Z',
  });
  @override
  Future<List<TrainerWorkout>> workouts({
    TrainerWorkout? before,
    String query = '',
    bool? running,
    String? format,
  }) async {
    libraryReads++;
    if (failWorkouts) throw StateError('Biblioteca no disponible');
    return before == null ? availableWorkouts ?? [entry] : [];
  }

  @override
  Future<WorkoutTemplate?> template(String id) async => privateRecipe;
  @override
  Future<List<WorkoutEditorExercise>> exercises({
    Set<String> retainedIds = const {},
  }) async => [const WorkoutEditorExercise(id: 'exercise', name: 'Dominadas')];
  @override
  Future<String> save(
    String operationId,
    CreatePersonalWorkoutInput input, {
    String? previousId,
  }) async {
    saved.add((id: operationId, input: input, previous: previousId));
    return pendingSave == null ? 'saved-version' : pendingSave!.future;
  }

  @override
  Future<void> assign({
    required String id,
    required String relationId,
    required String templateId,
    required DateTime date,
    String? note,
  }) async {
    assigned.add((
      id: id,
      relation: relationId,
      template: templateId,
      date: date,
      note: note,
    ));
    if (failAssign) throw StateError('Conexión interrumpida');
  }

  @override
  Future<List<TrainerAssignment>> assignments(
    String clientId, {
    TrainerAssignment? before,
    TrainerAssignmentVisibility visibility = TrainerAssignmentVisibility.all,
  }) async => [
    TrainerAssignment.fromJson({
      'id': 'assignment',
      'template_id': 'template',
      'template_name': privateRecipe.name,
      'template_version': 3,
      'scheduled_date': '2026-10-21',
      'status': 'completed',
      'execution_id': 'execution',
      'note': 'Prioriza la técnica',
      'created_at': '2026-10-21T10:00:00Z',
    }),
  ];
  @override
  Future<WorkoutJson?> result(String assignmentId) async => resultFixture;
  @override
  Future<void> cancel(String assignmentId) async {}
  @override
  Future<void> changeLifecycle({
    required String operationId,
    required TrainerAssignment assignment,
    required TrainerAssignmentLifecycleAction action,
  }) async {}
}

final resultFixture = <String, dynamic>{
  'template_name': privateRecipe.name,
  'template_version': 3,
  'status': 'completed',
  'started_at': '2026-10-21T10:00:00Z',
  'final_rpe': 6,
  'notes': 'Buenas sensaciones',
  'workout_amrap_results': [],
  'workout_execution_sets': [
    {
      'block_name': 'Bloque principal',
      'exercise_name': 'Dominadas',
      'set_order': 0,
      'block_format': 'straight_sets',
      'status': 'completed',
      'target_reps': 10,
      'target_load_kg': 5,
      'target_rir': 2,
      'actual_reps': 8,
      'actual_load_kg': 5,
      'actual_rir': 1,
      'rest_after_seconds': 90,
    },
  ],
};

Future<void> press(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      250,
      maxScrolls: 40,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'AMRAP muestra rondas realizadas sin inventar series incompletas',
    (tester) async {
      final amrap = <String, dynamic>{
        ...resultFixture,
        'workout_amrap_results': [
          {
            'block_order': 0,
            'completed_rounds': 4,
            'partial_item_order': 0,
            'partial_reps': 3,
          },
        ],
        'workout_execution_sets': [
          {
            'block_name': 'AMRAP',
            'exercise_name': 'Dominadas',
            'set_order': 0,
            'block_format': 'amrap',
            'status': 'pending',
            'target_reps': 10,
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: Scaffold(body: TrainerWorkoutResultContent(result: amrap)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('4 rondas completas'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('4 rondas completas'), findsOneWidget);
      expect(find.textContaining('series completadas'), findsNothing);
      expect(find.textContaining('Realizado: Sin registro'), findsNothing);
    },
  );
  testWidgets(
    'asignar reintenta la misma operación y previsualiza la receta concreta',
    (tester) async {
      final repo = WorkoutFixture()..failAssign = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => TrainerAssignmentDialog(
                    repository: repo,
                    relationId: 'relation',
                  ),
                ),
                child: const Text('Abrir pauta'),
              ),
            ),
          ),
        ),
      );
      await press(tester, 'Abrir pauta');
      await press(tester, privateRecipe.name);
      await press(tester, 'Ver receta antes de asignar');
      expect(find.byType(WorkoutTemplateContent), findsOneWidget);
      expect(find.text('1. Dominadas'), findsOneWidget);
      await press(tester, 'Volver a la pauta');
      await tester.enterText(find.byType(TextField), 'Prioriza la técnica');
      await press(tester, 'Asignar sesión');
      expect(repo.assigned, hasLength(1));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      repo.failAssign = false;
      await press(tester, 'Reintentar asignación');
      expect(repo.assigned, hasLength(2));
      expect(repo.assigned[1], repo.assigned[0]);
      expect(repo.assigned.singleOrNull, isNull);
      expect(find.byType(TrainerAssignmentDialog), findsNothing);
    },
  );
  testWidgets(
    'sesión elegida confirma sin cargar catálogo y conserva el día y destinatario',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = WorkoutFixture()..failWorkouts = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => TrainerAssignmentDialog(
                    repository: repo,
                    relationId: 'selected-pupil',
                    initialWorkout: repo.entry,
                    initialDate: DateTime(2026, 11, 3),
                  ),
                ),
                child: const Text('Abrir pauta'),
              ),
            ),
          ),
        ),
      );
      await press(tester, 'Abrir pauta');
      expect(repo.libraryReads, 0);
      expect(repo.assigned, isEmpty);
      expect(find.byType(RadioListTile<String>), findsNothing);
      expect(find.text(privateRecipe.name), findsOneWidget);
      expect(find.text('Versión 3'), findsOneWidget);
      expect(find.text('Fecha: 3/11/2026'), findsOneWidget);
      final confirm = find.widgetWithText(FilledButton, 'Asignar sesión');
      expect(tester.getRect(confirm).bottom, lessThan(720));
      expect(confirm.hitTestable(), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Controla el ritmo');
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repo.assigned.single.relation, 'selected-pupil');
      expect(repo.assigned.single.template, repo.entry.id);
      expect(repo.assigned.single.date, DateTime(2026, 11, 3));
      expect(repo.assigned.single.note, 'Controla el ritmo');
      expect(repo.libraryReads, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cambiar sesión abre la biblioteca bajo demanda sin perder fecha ni indicaciones',
    (tester) async {
      final repo = WorkoutFixture();
      final alternative = TrainerWorkout.fromJson({
        'id': 'alternative',
        'name': 'Carrera alternativa',
        'version': 2,
        'created_at': '2026-10-26T10:00:00Z',
      });
      repo.availableWorkouts = [alternative];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => TrainerAssignmentDialog(
                    repository: repo,
                    relationId: 'relation',
                    initialWorkout: repo.entry,
                    initialDate: DateTime(2026, 11, 4),
                  ),
                ),
                child: const Text('Abrir pauta'),
              ),
            ),
          ),
        ),
      );
      await press(tester, 'Abrir pauta');
      await tester.enterText(
        find.byType(TextField),
        'Mantén estas indicaciones',
      );
      await press(tester, 'Cambiar sesión');
      expect(repo.libraryReads, 1);
      expect(repo.assigned, isEmpty);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Asignar sesión'),
            )
            .onPressed,
        isNull,
      );
      await press(tester, alternative.name);
      expect(find.byType(RadioListTile<String>), findsNothing);
      expect(find.text('Fecha: 4/11/2026'), findsOneWidget);
      await press(tester, 'Asignar sesión');
      expect(repo.assigned.single.template, alternative.id);
      expect(repo.assigned.single.date, DateTime(2026, 11, 4));
      expect(repo.assigned.single.note, 'Mantén estas indicaciones');
    },
  );
  testWidgets(
    'revisión usa el creador común, conserva prescripción y espera confirmación',
    (tester) async {
      final repo = WorkoutFixture()..pendingSave = Completer<String>();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/edit'),
                child: const Text('Editar'),
              ),
            ),
          ),
          GoRoute(
            path: '/edit',
            builder: (_, _) => TrainerWorkoutEditorPage(
              repository: repo,
              templateId: 'template',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await press(tester, 'Editar');
      final name = find.widgetWithText(TextField, privateRecipe.name);
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Fuerza revisada');
      final save = find.text('Guardar nueva versión');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pump();
      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.previous, 'template');
      final set =
          repo.saved.single.input.blocks.single.exercises.single.sets.single;
      expect(
        (
          set.targetValue,
          set.targetLoadKg,
          set.targetRir,
          set.restAfterSeconds,
        ),
        (10.0, 5.0, 2.0, 90),
      );
      expect(find.byType(TrainerWorkoutEditorPage), findsOneWidget);
      repo.pendingSave!.complete('saved-version');
      await tester.pumpAndSettle();
      expect(find.byType(TrainerWorkoutEditorPage), findsNothing);
    },
  );
  testWidgets(
    'cliente inactivo conserva resultados con navegación y sin nueva asignación',
    (tester) async {
      final repo = WorkoutFixture();
      final access = FakeTrainerRepository()
        ..history = [trainerRelation('Alumno de regreso', ended: true)];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => TrainerClientWorkoutsPage(
              repository: repo,
              accessRepository: access,
              clientId: access.history.single.personId,
            ),
          ),
          GoRoute(
            path: '/clients/:id/workouts/:assignment/result',
            builder: (_, state) => TrainerWorkoutResultPage(
              repository: repo,
              assignmentId: state.pathParameters['assignment']!,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Asignar sesión privada'),
            )
            .onPressed,
        isNull,
      );
      await press(tester, 'Ver resultados');
      await tester.scrollUntilVisible(
        find.text('Buenas sensaciones'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Buenas sensaciones'), findsOneWidget);
      expect(find.text('Esfuerzo final'), findsOneWidget);
      expect(find.text('6/10'), findsOneWidget);
      await press(tester, 'Dominadas');
      expect(find.text('Realizado: 8 rep · 5 kg · 1 RIR'), findsOneWidget);
      expect(find.textContaining('Pautado: 10 rep'), findsOneWidget);
      expect(find.text('Corregir resultado'), findsNothing);
    },
  );
  testWidgets('muestra totales medidos sin calcularlos desde la confirmación', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainerWorkoutResultContent(
            result: {
              ...resultFixture,
              'observed_timer_seconds': 137.3,
              'observed_elapsed_seconds': 165.75,
              'observed_distance_meters': 410.25,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tiempo del reloj'), findsOneWidget);
    expect(find.text('2:17.30'), findsOneWidget);
    expect(find.text('Tiempo transcurrido'), findsOneWidget);
    expect(find.text('2:45.75'), findsOneWidget);
    expect(find.text('Distancia del reloj'), findsOneWidget);
    expect(find.text('0.41 km'), findsOneWidget);
    expect(find.text('Ritmo global calculado'), findsNothing);
  });
  testWidgets(
    'el ritmo usa temporizador y distancia, no el transcurrido ni la pauta',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainerWorkoutResultContent(
              result: {
                ...resultFixture,
                'observed_timer_seconds': 300.5,
                'observed_elapsed_seconds': 600,
                'observed_distance_meters': 1000,
                'workout_execution_sets': [],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ritmo global calculado'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrainerWorkoutResultContent(
              result: {
                ...resultFixture,
                'observed_timer_seconds': 300.5,
                'observed_elapsed_seconds': 600,
                'observed_distance_meters': 1000,
                'workout_execution_sets': [
                  {
                    ...((resultFixture['workout_execution_sets'] as List).single
                        as Map),
                    'block_format': 'running',
                    'actual_duration_seconds': 300.5,
                    'actual_distance_meters': 1000,
                  },
                ],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ritmo global calculado'), findsOneWidget);
      expect(find.text('5:00.50 min/km'), findsOneWidget);
      expect(find.text('10:00.00 min/km'), findsNothing);
    },
  );
  testWidgets('el resumen no inventa métricas del reloj sin mediciones', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainerWorkoutResultContent(result: resultFixture),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tiempo del reloj'), findsNothing);
    expect(find.text('Tiempo transcurrido'), findsNothing);
    expect(find.text('Distancia del reloj'), findsNothing);
    expect(find.text('Pulso medio'), findsNothing);
    expect(find.text('Ritmo global calculado'), findsNothing);
    expect(find.text('Declarado por el alumno'), findsOneWidget);
  });
  for (final width in [320.0, 1200.0]) {
    testWidgets('resultados y asignación legibles a $width con texto 2x', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget app(Widget child) => MaterialApp(
        theme: EntrenaTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: child,
      );
      await tester.pumpWidget(
        app(Scaffold(body: TrainerWorkoutResultContent(result: resultFixture))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: TrainerAssignmentDialog(
              repository: WorkoutFixture(),
              relationId: 'relation',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

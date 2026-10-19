import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_preview_page.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_program_workouts_page.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';

const _program = AdminProgram(
  id: 'tropa',
  name: 'Tropa',
  kind: 'access',
  enabled: false,
);

class _Programs extends Fake implements AdminProgramRepository {
  @override
  Future<bool> hasAccess() async => true;
  @override
  Future<List<AdminProgram>> listPrograms() async => [_program];
  @override
  Future<List<AdminProgramTest>> listTests(String id) async => [];
  @override
  Future<AdminProgramScoringRule?> getScoringRule(String id) async => null;
  @override
  Future<List<AdminProgramTrainingModule>> listTrainingModules(
    String id,
  ) async => [];
  @override
  Future<AdminPerformanceSetup> loadPerformanceSetup(String id) async =>
      const AdminPerformanceSetup([], []);
}

class _Exercises extends Fake implements AdminExerciseRepository {}

class _FakeWorkouts implements AdminWorkoutRepository {
  @override
  Future<void> setLibraryVisibility(
    String templateId,
    bool value, {
    required bool expected,
  }) async {}
  String scope = 'program';
  bool published = false;
  bool removed = false;
  int publishCalls = 0;
  int removeCalls = 0;
  List<AdminWorkoutProgramUsage> usages = [];

  @override
  Future<WorkoutTemplate?> getTemplateById(String templateId) async =>
      const WorkoutTemplate(
        id: 'template-1',
        name: 'Series 200 m',
        description: null,
        estimatedDurationMinutes: 8,
        version: 1,
        blocks: [
          WorkoutBlock(
            id: 'block-1',
            name: 'Carrera',
            format: WorkoutBlockFormat.running,
            rounds: 1,
            restAfterSeconds: 0,
            items: [
              WorkoutItem(
                id: 'item-1',
                exerciseId: runningExerciseId,
                exerciseName: 'Carrera',
                sets: [
                  WorkoutSet(
                    id: 'set-1',
                    order: 0,
                    targetDistanceMeters: 200,
                    targetPaceMinSecondsPerKm: 230,
                    targetPaceMaxSecondsPerKm: 230,
                    restAfterSeconds: 0,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  @override
  Future<List<AdminWorkoutSummary>> listForProgram(String programId) async => [
    if (!removed)
      AdminWorkoutSummary(
        id: 'template-1',
        name: 'Series 200 m',
        status: published ? 'published' : 'draft',
        version: 1,
        isRunning: true,
        catalogScope: scope,
        guidedPrograms: usages,
      ),
  ];

  @override
  Future<void> publishDraft(String templateId) async {
    publishCalls++;
    published = true;
  }

  @override
  Future<void> remove(String templateId) async {
    removeCalls++;
    removed = true;
  }

  @override
  Future<String> revise(
    String templateId,
    CreatePersonalWorkoutInput input,
  ) async => 'revised-id';

  @override
  Future<List<AdminWorkoutSummary>> listGeneral() => listForProgram('');

  @override
  Future<String> createDraft(
    String? programId,
    CreatePersonalWorkoutInput input, {
    bool showInLibrary = true,
  }) async => 'new-id';

  @override
  Future<List<AdminExercise>> listPublicExercises() async => const [];
}

Future<void> _previewAction(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    180,
    scrollable: find
        .descendant(
          of: find.byType(AdminWorkoutPreviewPage),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'muestra versiones y estados de uso, busca por programa y abre su editor',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FakeWorkouts()
        ..scope = 'general'
        ..usages = const [
          AdminWorkoutProgramUsage(
            id: 'routine-v1',
            name: 'Rutina compartida',
            version: 1,
            status: 'published',
          ),
          AdminWorkoutProgramUsage(
            id: 'routine-v2',
            name: 'Rutina compartida',
            version: 2,
            status: 'draft',
          ),
        ];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                AdminProgramWorkoutsPage(program: null, repository: repository),
          ),
          GoRoute(
            path: '/guided-programs/:id/edit',
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Editor ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rutina compartida · v1 · Publicado'), findsOneWidget);
      expect(find.text('Rutina compartida · v2 · Borrador'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar sesiones'),
        'compartida',
      );
      await tester.pumpAndSettle();
      expect(find.text('Series 200 m'), findsOneWidget);
      await tester.tap(find.text('Rutina compartida · v2 · Borrador'));
      await tester.pumpAndSettle();
      expect(find.text('Editor routine-v2'), findsOneWidget);
      repository.usages = [];
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.text('No hay sesiones con esta búsqueda y estado.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar sesiones'),
        '',
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin programas guiados asociados'), findsOneWidget);
      expect(repository.publishCalls, 0);
      expect(repository.removeCalls, 0);
    },
  );

  testWidgets(
    'nombres de programa largos admiten móvil estrecho y texto grande',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FakeWorkouts()
        ..scope = 'general'
        ..usages = const [
          AdminWorkoutProgramUsage(
            id: 'routine',
            name: 'Rutina de fuerza de empuje, tirón y pierna para iniciación',
            version: 12,
            status: 'archived',
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
          home: AdminProgramWorkoutsPage(program: null, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Rutina de fuerza'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('publicar exige confirmación y vuelve a cargar el estado', (
    tester,
  ) async {
    final repository = _FakeWorkouts();
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: createAdminRouter(
          programs: _Programs(),
          workouts: repository,
          exercises: _Exercises(),
          onSignOut: () {},
          initialLocation: '/programs/tropa/sessions',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Series 200 m'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3:50/km'), findsOneWidget);
    await _previewAction(tester, 'Publicar para el programa');
    expect(find.textContaining('plantilla de este programa'), findsOneWidget);
    expect(repository.publishCalls, 0);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.publishCalls, 0);

    await _previewAction(tester, 'Publicar para el programa');
    await tester.tap(find.text('Publicar para el programa').last);
    await tester.pumpAndSettle();
    expect(repository.publishCalls, 1);
    expect(find.text('Publicado'), findsOneWidget);
    expect(find.text('Publicar para el programa'), findsNothing);
  });

  testWidgets('la biblioteca general confirma publicación y borra borrador', (
    tester,
  ) async {
    final repository = _FakeWorkouts()..scope = 'general';
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: createAdminRouter(
          programs: _Programs(),
          workouts: repository,
          exercises: _Exercises(),
          onSignOut: () {},
          initialLocation: '/sessions',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sesiones generales de EntrenaOP'), findsOneWidget);
    await tester.tap(find.text('Series 200 m'));
    await tester.pumpAndSettle();
    await _previewAction(tester, 'Borrar borrador');
    expect(repository.removeCalls, 0);
    await tester.tap(find.text('Borrar borrador').last);
    await tester.pumpAndSettle();
    expect(repository.removeCalls, 1);
    expect(
      find.text('Todavía no hay sesiones en esta biblioteca.'),
      findsOneWidget,
    );
  });
}

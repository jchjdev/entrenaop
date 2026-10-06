import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_library_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'busca sin tildes y combina tipo y duración, conservando cada pestaña',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cubit = _searchCubit();
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: BlocProvider.value(
            value: cubit,
            child: const WorkoutLibraryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'TECNICA');
      await tester.pumpAndSettle();
      expect(find.text('Carrera técnica'), findsOneWidget);
      expect(find.text('Fuerza base'), findsOneWidget);
      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carrera').last);
      await tester.pumpAndSettle();
      expect(find.text('Carrera técnica'), findsOneWidget);
      expect(find.text('Fuerza base'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Más de 45 min').last);
      await tester.pumpAndSettle();
      expect(
        find.text('No hay sesiones que coincidan con tu búsqueda.'),
        findsOneWidget,
      );
      expect(find.text('Filtros (2)'), findsOneWidget);
      await tester.tap(find.text('Mis sesiones'));
      await tester.pumpAndSettle();
      expect(find.text('Sesión propia'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text('EntrenaOP'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'TECNICA',
      );
      await tester.tap(find.text('Limpiar búsqueda y filtros').first);
      await tester.pumpAndSettle();
      expect(find.text('Carrera técnica'), findsOneWidget);
      expect(find.text('Fuerza base'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('los filtros y tarjetas caben a 320 px con texto al doble', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cubit = _searchCubit();
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutLibraryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fuerza base'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Mis sesiones abre directamente el contenido personal', (
    tester,
  ) async {
    final repository = _Repository(
      const [],
      personalWorkouts: const [
        WorkoutTemplateSummary(
          id: 'mine',
          name: 'Sesión propia',
          description: null,
          estimatedDurationMinutes: 30,
          origin: WorkoutTemplateOrigin.user,
          version: 1,
        ),
      ],
    );
    final cubit = WorkoutLibraryCubit(
      getPublicWorkouts: GetPublicWorkoutsUseCase(repository),
      getPersonalWorkouts: GetPersonalWorkoutsUseCase(repository),
      duplicatePersonalWorkout: DuplicatePersonalWorkoutUseCase(repository),
      archivePersonalWorkout: ArchivePersonalWorkoutUseCase(repository),
    );
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutLibraryPage(initialPersonalTab: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sesión propia'), findsOneWidget);
    expect(find.text('Tus sesiones'), findsOneWidget);
    expect(find.text('Demostración · no es tu sesión asignada.'), findsNothing);
  });
  testWidgets('la biblioteca pública cabe en una pantalla móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _Repository(const [
      WorkoutTemplateSummary(
        id: 'template-1',
        name: 'Primera sesión · Fuerza base',
        description: 'Sesión pública para validar el motor.',
        estimatedDurationMinutes: 20,
        origin: WorkoutTemplateOrigin.system,
        version: 1,
      ),
    ]);
    final cubit = WorkoutLibraryCubit(
      getPublicWorkouts: GetPublicWorkoutsUseCase(repository),
      getPersonalWorkouts: GetPersonalWorkoutsUseCase(repository),
      duplicatePersonalWorkout: DuplicatePersonalWorkoutUseCase(repository),
      archivePersonalWorkout: ArchivePersonalWorkoutUseCase(repository),
    );
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/plan/library',
      routes: [
        GoRoute(
          path: '/plan/library',
          builder: (context, state) => BlocProvider.value(
            value: cubit,
            child: const WorkoutLibraryPage(),
          ),
          routes: [
            GoRoute(
              path: ':templateId',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Detalle de sesión')),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData.dark(useMaterial3: true),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sesiones de EntrenaOP'), findsOneWidget);
    expect(find.text('Primera sesión · Fuerza base'), findsOneWidget);
    expect(find.text('20 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una sesión personal sin descripción no aparece como pública', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _Repository(
      const [],
      personalWorkouts: const [
        WorkoutTemplateSummary(
          id: 'personal-1',
          name: 'Mi fuerza',
          description: null,
          estimatedDurationMinutes: 30,
          origin: WorkoutTemplateOrigin.user,
          version: 1,
        ),
      ],
    );
    final cubit = WorkoutLibraryCubit(
      getPublicWorkouts: GetPublicWorkoutsUseCase(repository),
      getPersonalWorkouts: GetPersonalWorkoutsUseCase(repository),
      duplicatePersonalWorkout: DuplicatePersonalWorkoutUseCase(repository),
      archivePersonalWorkout: ArchivePersonalWorkoutUseCase(repository),
    );
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/plan/library',
      routes: [
        GoRoute(
          path: '/plan/library',
          builder: (context, state) => BlocProvider.value(
            value: cubit,
            child: const WorkoutLibraryPage(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData.dark(useMaterial3: true),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis sesiones'));
    await tester.pumpAndSettle();

    expect(find.text('Mi fuerza'), findsOneWidget);
    expect(find.text('Sesión privada creada por ti.'), findsOneWidget);
    expect(find.text('Sesión pública de EntrenaOP.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

WorkoutLibraryCubit _searchCubit() {
  final repository = _Repository(
    const [
      WorkoutTemplateSummary(
        id: 'running',
        name: 'Carrera técnica',
        description: 'Rodaje tranquilo.',
        estimatedDurationMinutes: 35,
        origin: WorkoutTemplateOrigin.system,
        version: 1,
        isRunning: true,
      ),
      WorkoutTemplateSummary(
        id: 'strength',
        name: 'Fuerza base',
        description: 'Técnica de movimientos.',
        estimatedDurationMinutes: 25,
        origin: WorkoutTemplateOrigin.system,
        version: 1,
      ),
    ],
    personalWorkouts: const [
      WorkoutTemplateSummary(
        id: 'mine',
        name: 'Sesión propia',
        description: null,
        estimatedDurationMinutes: null,
        origin: WorkoutTemplateOrigin.user,
        version: 1,
      ),
    ],
  );
  return WorkoutLibraryCubit(
    getPublicWorkouts: GetPublicWorkoutsUseCase(repository),
    getPersonalWorkouts: GetPersonalWorkoutsUseCase(repository),
    duplicatePersonalWorkout: DuplicatePersonalWorkoutUseCase(repository),
    archivePersonalWorkout: ArchivePersonalWorkoutUseCase(repository),
  );
}

class _Repository implements WorkoutRepository {
  _Repository(this.workouts, {this.personalWorkouts = const []});

  final List<WorkoutTemplateSummary> workouts;
  final List<WorkoutTemplateSummary> personalWorkouts;

  @override
  Future<List<WorkoutTemplateSummary>> getPublicTemplates() async => workouts;

  @override
  Future<List<WorkoutTemplateSummary>> getPersonalTemplates() async =>
      personalWorkouts;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import 'package:entrenaop/features/pro/domain/pro_access.dart';

import '../../support/pro_access_fixture.dart';

import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/features/dashboard/domain/repositories/home_favorites_repository.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_favorites.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/create_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercise_by_id_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/update_exercise_usecase.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_library_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_image.dart';

void main() {
  setUp(
    () => sl.registerSingleton<ProAccessRepository>(
      ProAccessFixture(isPro: true),
    ),
  );
  for (final width in [390.0, 1000.0]) {
    for (final path in [
      '/plan/starter-session',
      '/plan/library/session-test',
    ]) {
      testWidgets(
        'vista de sesión dedicada y regreso al origen: $path, $width',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 950));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          _register(_Exercises());
          addTearDown(sl.reset);
          final auth = _Auth();
          final router = AppRouter(auth);
          addTearDown(router.dispose);
          router.config.go('/library/exercises?tab=personal');
          await tester.pumpWidget(_app(auth, router));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'privado');
          await tester.pumpAndSettle();
          router.config.push(path);
          await tester.pumpAndSettle();
          expect(find.text('Vista de la sesión'), findsOneWidget);
          expect(find.byType(NavigationBar), findsNothing);
          expect(find.byType(NavigationRail), findsNothing);
          await tester.tap(find.byTooltip('Volver'));
          await tester.pumpAndSettle();
          expect(
            router.config.routeInformationProvider.value.uri.toString(),
            '/library/exercises?tab=personal',
          );
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'privado',
          );
          expect(find.text('Ejercicio privado'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Un enlace directo también debe abrir sin navegación de secciones.
          router.config.go(path);
          await tester.pumpAndSettle();
          expect(find.text('Vista de la sesión'), findsOneWidget);
          expect(find.byType(NavigationBar), findsNothing);
          expect(find.byType(NavigationRail), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Volver'));
          await tester.pumpAndSettle();
          expect(
            router.config.routeInformationProvider.value.uri.path,
            path == '/plan/starter-session' ? '/library' : '/plan/library',
          );
          expect(
            width < 840
                ? find.byType(NavigationBar)
                : find.byType(NavigationRail),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('la colección se renueva al cambiar de cuenta en la misma ruta', (
    tester,
  ) async {
    final repository = _Exercises()
      ..exercises.add(_exercise('Ejercicio de otra cuenta', owner: 'other'));
    _register(repository);
    addTearDown(sl.reset);
    final auth = _SwitchableAuth();
    addTearDown(auth.close);
    final router = AppRouter(auth);
    addTearDown(router.dispose);
    router.config.go('/library/exercises?tab=personal');
    await tester.pumpWidget(_app(auth, router));
    await tester.pumpAndSettle();
    expect(find.text('Ejercicio privado'), findsOneWidget);
    expect(find.text('Ejercicio de otra cuenta'), findsNothing);
    auth.change('other');
    await tester.pumpAndSettle();
    expect(find.text('Ejercicio privado'), findsNothing);
    expect(find.text('Ejercicio de otra cuenta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'editar conserva búsqueda, protege el borrador y reintenta sin perder campos',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Exercises()..failUpdate = true;
      _register(repository);
      addTearDown(sl.reset);
      final auth = _Auth();
      final router = AppRouter(auth);
      addTearDown(router.dispose);
      router.config.go('/library/exercises?tab=personal');
      await tester.pumpWidget(_app(auth, router));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'privado');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ejercicio privado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar ejercicio'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      final name = find.byKey(const ValueKey('personal-exercise-name'));
      await tester.enterText(name, 'Ejercicio privado mejorado');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      await tester.tap(find.text('Seguir aquí'));
      await tester.pumpAndSettle();
      final save = find.text('Guardar ejercicio');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.textContaining('Puedes reintentarlo.'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(name).controller!.text,
        'Ejercicio privado mejorado',
      );
      repository.failUpdate = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        router.config.routeInformationProvider.value.uri.path,
        '/library/exercises',
      );
      expect(find.text('Ejercicio privado mejorado'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'privado',
      );
      expect(repository.updated, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('un enlace directo no permite editar ejercicios oficiales', (
    tester,
  ) async {
    _register(_Exercises());
    addTearDown(sl.reset);
    final auth = _Auth();
    final router = AppRouter(auth);
    addTearDown(router.dispose);
    router.config.go('/library/exercises/Sentadilla%20de%20cat%C3%A1logo/edit');
    await tester.pumpWidget(_app(auth, router));
    await tester.pumpAndSettle();
    expect(
      find.text('Este ejercicio no está disponible para editar.'),
      findsOneWidget,
    );
    expect(find.text('Guardar ejercicio'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final (route, content) in [
    ('/library', 'Sesiones EntrenaOP'),
    ('/library/exercises', 'Sentadilla de catálogo'),
    (HomeShortcut.personalExercises.route, 'Ejercicio privado'),
    ('/plan/library', 'Sesiones de EntrenaOP'),
    (HomeShortcut.personalSessions.route, 'Tus sesiones'),
  ]) {
    testWidgets('$route pertenece a Biblioteca y conserva el enlace', (
      tester,
    ) async {
      final repository = _Exercises();
      _register(repository);
      addTearDown(sl.reset);
      final auth = _Auth();
      final router = AppRouter(auth);
      addTearDown(router.dispose);
      router.config.go(route);
      await tester.pumpWidget(_app(auth, router));
      await tester.pumpAndSettle();
      expect(
        router.config.routeInformationProvider.value.uri.toString(),
        route,
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations, hasLength(5));
      expect(bar.selectedIndex, 2);
      expect(find.text(content), findsOneWidget);
      if (route.contains('tab=personal') && route.contains('exercises')) {
        expect(find.text('Sentadilla de catálogo'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'el creador real de ejercicios vuelve a la colección y la recarga',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Exercises();
      _register(repository);
      addTearDown(sl.reset);
      final auth = _Auth();
      final router = AppRouter(auth);
      addTearDown(router.dispose);
      router.config.go('/library');
      await tester.pumpWidget(_app(auth, router));
      await tester.pumpAndSettle();
      final create = find.text('Crear ejercicio');
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.text('Crear ejercicio personal'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('personal-exercise-name')),
        'Mi remo',
      );
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      await tester.tap(find.text('Seguir aquí'));
      await tester.pumpAndSettle();
      expect(find.text('Mi remo'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('personal-exercise-muscles')),
        'espalda',
      );
      final save = find.text('Guardar ejercicio');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.created, 1);
      expect(find.text('Mi remo'), findsOneWidget);
      expect(
        router.config.routeInformationProvider.value.uri.toString(),
        '/library/exercises?tab=personal',
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'volver a pulsar Biblioteca recupera su portada desde una colección',
    (tester) async {
      _register(_Exercises());
      addTearDown(sl.reset);
      final auth = _Auth();
      final router = AppRouter(auth);
      addTearDown(router.dispose);
      router.config.go('/plan/library?tab=personal');
      await tester.pumpWidget(_app(auth, router));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(NavigationDestination, 'Biblioteca'),
      );
      await tester.pumpAndSettle();
      expect(router.config.routeInformationProvider.value.uri.path, '/library');
      expect(find.text('Sesiones EntrenaOP'), findsOneWidget);
    },
  );
}

Widget _app(AuthCubit auth, AppRouter router) => BlocProvider<AuthCubit>.value(
  value: auth,
  child: MaterialApp.router(
    theme: EntrenaTheme.dark,
    routerConfig: router.config,
  ),
);

void _register(_Exercises repository) {
  sl.registerSingleton(GetExercisesUseCase(repository));
  sl.registerSingleton(CreateExerciseUseCase(repository));
  sl.registerSingleton(GetExerciseByIdUseCase(repository));
  sl.registerSingleton(UpdateExerciseUseCase(repository));
  final workouts = _Workouts();
  sl.registerFactoryParam<WorkoutPreviewCubit, String, void>(
    (id, _) => WorkoutPreviewCubit(
      templateId: id,
      getWorkoutTemplate: GetWorkoutTemplateUseCase(workouts),
      startExecution: StartWorkoutExecutionUseCase(workouts),
    )..load(),
  );
  sl.registerFactory(
    () => WorkoutLibraryCubit(
      getPublicWorkouts: GetPublicWorkoutsUseCase(workouts),
      getPersonalWorkouts: GetPersonalWorkoutsUseCase(workouts),
      duplicatePersonalWorkout: DuplicatePersonalWorkoutUseCase(workouts),
      archivePersonalWorkout: ArchivePersonalWorkoutUseCase(workouts),
    )..load(),
  );
}

class _Auth implements AuthCubit {
  @override
  AuthState get state => AuthAuthenticated(
    user: UserEntity(
      id: 'me',
      email: 'me@example.test',
      role: 'free',
      createdAt: DateTime(2026),
    ),
  );
  @override
  Stream<AuthState> get stream => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Exercises implements ExerciseRepository {
  int created = 0;
  int updated = 0;
  bool failUpdate = false;
  final exercises = [
    _exercise('Sentadilla de catálogo', official: true),
    _exercise('Ejercicio privado'),
  ];
  @override
  Future<List<ExerciseEntity>> getExercises() async => List.of(exercises);
  @override
  Future<ExerciseEntity?> getExerciseById(String id) async =>
      exercises.where((e) => e.id == id).firstOrNull;
  @override
  Future<void> updateExercise(
    ExerciseEntity exercise, {
    ExerciseImageUpload? image,
    bool removeImage = false,
  }) async {
    if (failUpdate) throw Exception('Fallo simulado');
    updated++;
    exercises[exercises.indexWhere((e) => e.id == exercise.id)] = exercise;
  }

  @override
  Future<ExerciseEntity> createExercise(
    PersonalExerciseDraft draft, {
    ExerciseImageUpload? image,
  }) async {
    created++;
    final exercise = _exercise(draft.name);
    exercises.add(exercise);
    return exercise;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ExerciseEntity _exercise(
  String name, {
  bool official = false,
  String owner = 'me',
}) => ExerciseEntity(
  id: name,
  name: name,
  muscleGroups: const ['piernas'],
  equipment: const [],
  difficulty: 'inicial',
  exerciseType: 'repeticiones',
  isPublic: official,
  origin: official ? ExerciseOrigin.system : ExerciseOrigin.user,
  createdBy: official ? null : owner,
);

class _SwitchableAuth extends Cubit<AuthState> implements AuthCubit {
  _SwitchableAuth() : super(_stateFor('me'));
  void change(String userId) => emit(_stateFor(userId));
  static AuthState _stateFor(String userId) => AuthAuthenticated(
    user: UserEntity(
      id: userId,
      email: '$userId@example.invalid',
      role: 'free',
      createdAt: DateTime(2026),
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Workouts implements WorkoutRepository {
  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async => null;
  @override
  Future<List<WorkoutTemplateSummary>> getPublicTemplates() async => [];
  @override
  Future<List<WorkoutTemplateSummary>> getPersonalTemplates() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/create_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_library_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/exercise_image.dart';

void main() {
  for (final (route, content) in [
    ('/library', 'Sesiones EntrenaOP'),
    ('/library/exercises', 'Sentadilla de catálogo'),
    ('/library/exercises?tab=personal', 'Ejercicio privado'),
    ('/plan/library', 'Sesiones de EntrenaOP'),
    ('/plan/library?tab=personal', 'Tus sesiones'),
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
  final workouts = _Workouts();
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
  final exercises = [
    _exercise('Sentadilla de catálogo', official: true),
    _exercise('Ejercicio privado'),
  ];
  @override
  Future<List<ExerciseEntity>> getExercises() async => List.of(exercises);
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

ExerciseEntity _exercise(String name, {bool official = false}) =>
    ExerciseEntity(
      id: name,
      name: name,
      muscleGroups: const ['piernas'],
      equipment: const [],
      difficulty: 'beginner',
      exerciseType: 'strength',
      isPublic: official,
      origin: official ? ExerciseOrigin.system : ExerciseOrigin.user,
      createdBy: official ? null : 'me',
    );

class _Workouts implements WorkoutRepository {
  @override
  Future<List<WorkoutTemplateSummary>> getPublicTemplates() async => [];
  @override
  Future<List<WorkoutTemplateSummary>> getPersonalTemplates() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

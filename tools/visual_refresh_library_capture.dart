// Widgets actuales y datos ficticios. No accede a cuentas ni a Supabase.
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/update_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/presentation/bloc/exercise_library_cubit.dart';
import 'package:entrenaop/features/exercises/presentation/pages/exercise_library_page.dart';
import 'package:entrenaop/features/exercises/presentation/pages/personal_exercise_creator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/exercise_image.dart';

import 'visual_atlas_capture.dart';

void main() {
  atlasSource = 'tools/visual_refresh_library_capture.dart';
  for (final (personal, width) in [
    (false, 390.0),
    (true, 390.0),
    (false, 1100.0),
  ]) {
    atlasTestWidgets('Biblioteca ejercicios $personal $width', (tester) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repository();
      final cubit = ExerciseLibraryCubit(
        getExercises: GetExercisesUseCase(repo),
        userId: 'fixture',
      );
      addTearDown(cubit.close);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: ExerciseLibraryPage(initialPersonalTab: personal),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await cubit.load();
      await atlasPumpWidget(
        tester,
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await atlasSettle(tester);
      await tester.tap(
        find.text(personal ? 'Mi remo unilateral' : 'Dominadas'),
      );
      await atlasSettle(tester);
      expect(
        find.text(personal ? 'Editar ejercicio' : 'Ver vídeo'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    atlasTestWidgets('Editor personal $width $scale', (tester) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repository();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => PersonalExerciseCreatorPage.edit(
              exercise: _personal,
              update: UpdateExerciseUseCase(repo),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await atlasPumpWidget(
        tester,
        MaterialApp.router(
          theme: EntrenaTheme.dark,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      );
      await atlasSettle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('personal-exercise-name')),
        'Mi remo mejorado',
      );
      await tester.ensureVisible(find.text('Guardar ejercicio'));
      await atlasSettle(tester);
      await tester.tap(find.text('Guardar ejercicio'));
      await atlasSettle(tester);
      expect(find.textContaining('Puedes reintentarlo.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

const _personal = ExerciseEntity(
  id: 'personal',
  name: 'Mi remo unilateral',
  description: 'Controla la bajada y mantén el tronco estable.',
  muscleGroups: ['espalda', 'bíceps'],
  equipment: ['mancuerna'],
  difficulty: 'intermedio',
  exerciseType: 'repeticiones',
  isPublic: false,
  origin: ExerciseOrigin.user,
  createdBy: 'fixture',
);

class _Repository implements ExerciseRepository {
  @override
  Future<List<ExerciseEntity>> getExercises() async => [
    const ExerciseEntity(
      id: 'pull',
      name: 'Dominadas',
      description: 'Sube de forma controlada, sin balancear el cuerpo.',
      videoUrl: 'https://example.invalid/dominadas.mp4',
      muscleGroups: ['espalda', 'bíceps'],
      equipment: ['barra'],
      difficulty: 'intermedio',
      exerciseType: 'repeticiones',
      isPublic: true,
      origin: ExerciseOrigin.system,
    ),
    _personal,
  ];
  @override
  Future<void> updateExercise(
    ExerciseEntity exercise, {
    ExerciseImageUpload? image,
    bool removeImage = false,
  }) async => throw StateError('Fallo ficticio para comprobar el reintento');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

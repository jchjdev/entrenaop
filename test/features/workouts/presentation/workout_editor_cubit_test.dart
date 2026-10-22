import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/create_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_editor_draft_store.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_state.dart';
import 'package:entrenaop/features/pro/domain/pro_access.dart';
import 'package:entrenaop/features/workouts/presentation/pages/running_workout_editor_page.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/exercise_image.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';
import 'package:workout_editor_ui/strength_set_fields.dart';
import 'package:workout_editor_ui/workout_effort_field.dart';
import 'package:workout_editor_ui/workout_format_field.dart';
import 'package:entrena_ui/entrena_ui.dart' show EntrenaInputPolicy;

import '../../exercises/domain/strength_exercise_catalog_test.dart'
    show readCatalogJson;
import '../../../helpers/performance_visual_review.dart';

void main() {
  setUpAll(() => loadReviewFont(always: true));
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('bloques y campos del editor a $width px y texto $scale', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final repository = _WorkoutRepository();
        final cubit = WorkoutEditorCubit(
          getExercises: GetExercisesUseCase(_ExerciseRepository()),
          createExercise: CreateExerciseUseCase(_ExerciseRepository()),
          draftStore: _DraftStore(),
          createWorkout: CreatePersonalWorkoutUseCase(repository),
          getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
          reviseWorkout: RevisePersonalWorkoutUseCase(repository),
          templateId: 'template-v1',
        );
        addTearDown(cubit.close);
        await cubit.load();
        await t.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('review-boundary'),
            child: MaterialApp(
              theme: EntrenaTheme.dark,
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: EntrenaInputPolicy(child: child!),
              ),
              home: BlocProvider.value(
                value: cubit,
                child: const WorkoutEditorPage(),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final name = _editorField('Nombre del bloque');
        await _show(t, name);
        await t.pumpAndSettle();
        await capturePerformanceWidget(
          t,
          'pulido-editor-bloque-${width.toInt()}-$scale',
        );
        final selector = find.byType(WorkoutFormatField);
        for (final (slug, format) in [
          ('series', 'Series convencionales'),
          ('superserie', 'Superserie'),
          ('circuito', 'Circuito'),
          ('intervalos', 'Intervalos de trabajo'),
          ('emom', 'EMOM · cada minuto'),
          ('amrap', 'AMRAP · máximas vueltas'),
          ('tabata', 'Tabata · 8 × 20/10'),
        ]) {
          await _show(t, selector);
          await t.pumpAndSettle();
          await t.tap(selector);
          await t.pumpAndSettle();
          await _show(t, find.text(format).last);
          await t.pumpAndSettle();
          await t.tap(find.text(format).last);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          for (final decorator in t.widgetList<InputDecorator>(
            find.byType(InputDecorator),
          )) {
            final label = decorator.decoration.labelText;
            if (label == null) continue;
            for (final element in find.text(label).evaluate()) {
              final paragraph = element.renderObject;
              if (paragraph is RenderParagraph) {
                expect(
                  paragraph.didExceedMaxLines,
                  isFalse,
                  reason: '$label completo en $slug a $width/$scale',
                );
              }
            }
          }
          await Scrollable.ensureVisible(t.element(name), alignment: .08);
          await t.pumpAndSettle();
          await capturePerformanceWidget(
            t,
            'compacto-editor-$slug-${width.toInt()}-$scale',
          );
          if (slug == 'tabata') {
            expect(
              find.text('20 s de trabajo · 10 s de recuperación'),
              findsWidgets,
            );
            continue;
          }
          final fields = find.byType(StrengthSetFields).first;
          await _show(t, fields);
          await Scrollable.ensureVisible(t.element(fields), alignment: .1);
          await t.pumpAndSettle();
          final position = t
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          position.jumpTo(
            (position.pixels - 24).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
          await t.pumpAndSettle();
          await capturePerformanceWidget(
            t,
            'compacto-editor-$slug-campos-${width.toInt()}-$scale',
          );
          if (format == 'Circuito' || format == 'AMRAP · máximas vueltas') {
            await _show(t, selector);
            await t.pumpAndSettle();
            await capturePerformanceWidget(
              t,
              'pulido-editor-${format.startsWith('Circuito') ? 'circuito' : 'amrap'}-${width.toInt()}-$scale',
            );
          }
        }
      });
    }
  }
  testWidgets('series, RIR y teclado se actualizan sin salir del editor', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final repository = _WorkoutRepository();
    final drafts = _DraftStore();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(_ExerciseRepository()),
      createExercise: CreateExerciseUseCase(_ExerciseRepository()),
      draftStore: drafts,
      createWorkout: CreatePersonalWorkoutUseCase(repository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
      reviseWorkout: RevisePersonalWorkoutUseCase(repository),
      templateId: 'template-v1',
    );
    addTearDown(cubit.close);
    await cubit.load();
    await t.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('review-boundary'),
        child: MaterialApp(
          theme: EntrenaTheme.dark,
          debugShowCheckedModeBanner: false,
          home: BlocProvider.value(
            value: cubit,
            child: const WorkoutEditorPage(),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final series = _editorField('Series');
    await _show(t, series);
    await t.enterText(series, '2');
    await t.pumpAndSettle();
    final effort = find.byType(WorkoutEffortField).first;
    await _show(t, effort);
    await t.tap(effort);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, '3'));
    await t.pumpAndSettle();
    final target = _editorField('Cantidad').first;
    await _show(t, target);
    await t.enterText(target, '8');
    await t.pump(const Duration(seconds: 1));
    expect(
      drafts.draft!.input.blocks.single.exercises.single.sets.map(
        (s) => s.targetValue,
      ),
      [8, 8],
    );
    expect(
      drafts.draft!.input.blocks.single.exercises.single.sets.map(
        (s) => s.targetRir,
      ),
      [3, 3],
    );
    expect(t.testTextInput.isVisible, isTrue);
    await _show(t, find.text('Bloque 1'));
    await t.tap(find.text('Bloque 1'));
    await t.pumpAndSettle();
    expect(t.testTextInput.isVisible, isFalse);
    await capturePerformanceWidget(t, 'editor-series-repeticiones-390');
    final customize = find.text('Personalizar cada serie');
    await _show(t, customize);
    await t.tap(customize);
    await t.pumpAndSettle();
    final second = _editorField('Objetivo').last;
    await _show(t, second);
    await t.enterText(second, '12');
    await t.pump(const Duration(seconds: 1));
    expect(
      drafts.draft!.input.blocks.single.exercises.single.sets.map(
        (s) => s.targetValue,
      ),
      [8, 12],
    );
    await t.enterText(second, '');
    await t.pump(const Duration(seconds: 1));
    expect(
      drafts.draft!.input.blocks.single.exercises.single.sets.map(
        (s) => s.targetValue,
      ),
      [8, 8],
    );
    await capturePerformanceWidget(t, 'compacto-series-dos-390');
    final selector = find.byType(DropdownButtonFormField<WorkoutTargetType>);
    await _show(t, selector);
    await t.tap(selector);
    await t.pumpAndSettle();
    await t.tap(find.text('Duración').last);
    await t.pumpAndSettle();
    expect(find.byType(WorkoutEffortField), findsNothing);
    final time = _editorField('Tiempo').first;
    await _show(t, time);
    await t.enterText(time, '40');
    await t.pump(const Duration(seconds: 1));
    expect(
      drafts.draft!.input.blocks.single.exercises.single.sets.map(
        (s) => s.targetValue,
      ),
      [40, 40],
    );
    await capturePerformanceWidget(t, 'editor-series-tiempo-390');
    await t.drag(find.byType(ListView).first, const Offset(0, -80));
    await t.pumpAndSettle();
    expect(t.testTextInput.isVisible, isFalse);
    await _show(t, selector);
    await t.tap(selector);
    await t.pumpAndSettle();
    await t.tap(find.text('Repeticiones').last);
    await t.pumpAndSettle();
    expect(
      t.widget<WorkoutEffortField>(find.byType(WorkoutEffortField).first).value,
      3,
    );
    expect(t.takeException(), isNull);
  });

  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('carrera Compacto completa a $width/$scale y teclado', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final repository = _WorkoutRepository();
      final cubit = WorkoutEditorCubit(
        getExercises: GetExercisesUseCase(_ExerciseRepository()),
        createExercise: CreateExerciseUseCase(_ExerciseRepository()),
        draftStore: _DraftStore(),
        createWorkout: CreatePersonalWorkoutUseCase(repository),
        getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
        reviseWorkout: RevisePersonalWorkoutUseCase(repository),
        runningEditor: true,
      );
      addTearDown(cubit.close);
      await cubit.load();
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: MaterialApp(
            theme: EntrenaTheme.dark,
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: EntrenaInputPolicy(child: child!),
            ),
            home: BlocProvider.value(
              value: cubit,
              child: const RunningWorkoutEditorPage(),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final name = _editorField('Nombre de la sesión');
      await t.enterText(name, 'Series de carrera');
      await t.pumpAndSettle();
      await t.tapAt(const Offset(5, 200));
      await t.pumpAndSettle();
      await capturePerformanceWidget(
        t,
        'compacto-carrera-${width.toInt()}-$scale-ficha',
      );
      await _chooseRunningPace(t);
      final pace = _editorField('Ritmo (m:ss/km)');
      await _show(t, pace);
      await t.pumpAndSettle();
      await capturePerformanceWidget(
        t,
        'compacto-carrera-${width.toInt()}-$scale-campos',
      );
      await t.enterText(pace, '500');
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isTrue);
      await t.tapAt(const Offset(5, 200));
      await t.pumpAndSettle();
      expect(t.testTextInput.isVisible, isFalse);
      expect(find.text('05:00'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  test(
    'una cuota rechazada conserva el borrador y devuelve el motivo comercial',
    () async {
      final repository = _WorkoutRepository()..denyCreation = true;
      final draftStore = _DraftStore();
      final cubit = WorkoutEditorCubit(
        getExercises: GetExercisesUseCase(_ExerciseRepository()),
        createExercise: CreateExerciseUseCase(_ExerciseRepository()),
        draftStore: draftStore,
        createWorkout: CreatePersonalWorkoutUseCase(repository),
        getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
        reviseWorkout: RevisePersonalWorkoutUseCase(repository),
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.persistDraft(_input);
      final savedDraft = draftStore.draft;
      await cubit.save(_input);
      expect(cubit.state.status, WorkoutEditorStatus.ready);
      expect(cubit.state.accessDenied?.restriction, ProRestriction.sessions);
      expect(cubit.state.createdTemplateId, isNull);
      expect(draftStore.draft, same(savedDraft));
      repository.denyCreation = false;
      await cubit.save(_input);
      expect(cubit.state.status, WorkoutEditorStatus.saved);
      expect(draftStore.draft, isNull);
    },
  );
  for (final save in [false, true]) {
    testWidgets(
      'el editor devuelve el control al router al salir, guardado $save',
      (tester) async {
        final repository = _WorkoutRepository();
        final cubit = WorkoutEditorCubit(
          getExercises: GetExercisesUseCase(_ExerciseRepository()),
          createExercise: CreateExerciseUseCase(_ExerciseRepository()),
          draftStore: _DraftStore(),
          createWorkout: CreatePersonalWorkoutUseCase(repository),
          getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
          reviseWorkout: RevisePersonalWorkoutUseCase(repository),
          templateId: 'template-v1',
        );
        addTearDown(cubit.close);
        await cubit.load();
        final router = GoRouter(
          initialLocation: '/origin',
          routes: [
            GoRoute(
              path: '/origin',
              builder: (_, _) => const Scaffold(body: Text('Mi biblioteca')),
            ),
            GoRoute(
              path: '/editor',
              builder: (_, _) => BlocProvider.value(
                value: cubit,
                child: const WorkoutEditorPage(),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        final returned = router.push<String>('/editor');
        await tester.pumpAndSettle();
        if (save) {
          await cubit.save(_input);
        } else {
          await tester.tap(find.byTooltip('Volver'));
        }
        await tester.pumpAndSettle();
        expect(await returned, save ? 'template-v2' : null);
        expect(router.state.uri.path, '/origin');
        expect(find.text('Mi biblioteca'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'EntrenaOP busca y añade variantes de la biblioteca de 63 ejercicios',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final exerciseRepository = _StrengthCatalogRepository();
      final workoutRepository = _WorkoutRepository();
      final cubit = WorkoutEditorCubit(
        getExercises: GetExercisesUseCase(exerciseRepository),
        createExercise: CreateExerciseUseCase(exerciseRepository),
        draftStore: _DraftStore(),
        createWorkout: CreatePersonalWorkoutUseCase(workoutRepository),
        getWorkoutTemplate: GetWorkoutTemplateUseCase(workoutRepository),
        reviseWorkout: RevisePersonalWorkoutUseCase(workoutRepository),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(
        cubit.state.exercises.where((e) => e.origin == ExerciseOrigin.system),
        hasLength(63),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const WorkoutEditorPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final addExercise = find.text('Buscar ejercicio del catálogo').first;
      await _show(tester, addExercise);
      await tester.pumpAndSettle();
      await tester.tap(addExercise);
      await tester.pumpAndSettle();
      await tester.tap(find.text('EntrenaOP'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar'),
        'Dominada prona',
      );
      await tester.pumpAndSettle();
      expect(find.text('Dominada prona'), findsNWidgets(2));
      expect(find.text('Dominada prona personal'), findsNothing);
      await tester.tap(find.text('Dominada prona').last);
      await tester.pumpAndSettle();
      expect(find.text('Buscar ejercicio'), findsNothing);
      expect(
        find.textContaining('Cambiar ejercicio · Dominada prona'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('carga una sesión existente y guarda una revisión', () async {
    final workoutRepository = _WorkoutRepository();
    final draftStore = _DraftStore()
      ..draft = WorkoutEditorDraftSnapshot(
        input: _input,
        savedAt: DateTime(2026, 9, 21),
      );
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(_ExerciseRepository()),
      createExercise: CreateExerciseUseCase(_ExerciseRepository()),
      draftStore: draftStore,
      createWorkout: CreatePersonalWorkoutUseCase(workoutRepository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(workoutRepository),
      reviseWorkout: RevisePersonalWorkoutUseCase(workoutRepository),
      templateId: 'template-v1',
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, WorkoutEditorStatus.ready);
    expect(cubit.state.originalTemplate?.version, 1);

    await cubit.save(_input);

    expect(cubit.state.status, WorkoutEditorStatus.saved);
    expect(cubit.state.createdTemplateId, 'template-v2');
    expect(workoutRepository.revisedTemplateId, 'template-v1');
    expect(draftStore.draft, isNull);
  });

  test('añade un ejercicio propio al catálogo del editor', () async {
    final exerciseRepository = _ExerciseRepository();
    final workoutRepository = _WorkoutRepository();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(exerciseRepository),
      createExercise: CreateExerciseUseCase(exerciseRepository),
      draftStore: _DraftStore(),
      createWorkout: CreatePersonalWorkoutUseCase(workoutRepository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(workoutRepository),
      reviseWorkout: RevisePersonalWorkoutUseCase(workoutRepository),
    );
    addTearDown(cubit.close);
    await cubit.load();

    final created = await cubit.createExercise(
      const PersonalExerciseDraft(
        name: 'Press francés',
        muscleGroups: ['tríceps'],
        equipment: ['mancuerna'],
        difficulty: 'intermedio',
        exerciseType: 'repeticiones',
      ),
    );

    expect(created.name, 'Press francés');
    expect(cubit.state.exercises.map((item) => item.name), [
      'Dominadas',
      'Press francés',
    ]);
  });

  testWidgets('permite configurar formatos y bloques en móvil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _WorkoutRepository();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(_ExerciseRepository()),
      createExercise: CreateExerciseUseCase(_ExerciseRepository()),
      draftStore: _DraftStore(),
      createWorkout: CreatePersonalWorkoutUseCase(repository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
      reviseWorkout: RevisePersonalWorkoutUseCase(repository),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutEditorPage(),
        ),
      ),
    );
    await tester.pump();
    final formatSelector = find.byType(
      DropdownButtonFormField<WorkoutBlockFormat>,
    );
    await _show(tester, formatSelector);
    await _show(tester, formatSelector);
    await tester.tap(formatSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Superserie').last);
    await tester.pumpAndSettle();

    expect(
      find.byType(DropdownButtonFormField<WorkoutBlockFormat>),
      findsOneWidget,
    );
    expect(find.textContaining('Dos ejercicios alternados'), findsOneWidget);
    await _show(tester, formatSelector);
    await tester.tap(formatSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tabata · 8 × 20/10').last);
    await tester.pumpAndSettle();
    expect(find.text('20 s de trabajo · 10 s de recuperación'), findsWidgets);
    expect(find.byType(StrengthSetFields), findsNothing);
    await _show(tester, formatSelector);
    await tester.tap(formatSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('EMOM · cada minuto').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Cada estación ocupa un minuto'),
      findsOneWidget,
    );
    await _show(tester, formatSelector);
    await tester.tap(formatSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('AMRAP · máximas vueltas').last);
    await tester.pumpAndSettle();
    await _show(tester, _editorField('Límite global (m:ss)'));
    expect(
      find.textContaining('Tantas vueltas como sea posible'),
      findsOneWidget,
    );
    final addBlock = find.byKey(const ValueKey('add-workout-block'));
    await _show(tester, addBlock);
    await tester.pumpAndSettle();
    await tester.tap(addBlock);
    await tester.pump();

    expect(find.text('Bloque 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('agrupa series de carrera y estima su duración por ritmo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _WorkoutRepository();
    final draftStore = _DraftStore();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(_ExerciseRepository()),
      createExercise: CreateExerciseUseCase(_ExerciseRepository()),
      draftStore: draftStore,
      createWorkout: CreatePersonalWorkoutUseCase(repository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
      reviseWorkout: RevisePersonalWorkoutUseCase(repository),
      runningEditor: true,
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider.value(
          value: cubit,
          child: const RunningWorkoutEditorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _show(tester, _editorField('Distancia (m)'));
    await tester.enterText(_editorField('Distancia (m)'), '1000');
    await _show(tester, find.text('Repetir último'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repetir último'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '4');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('Carrera × 4'), findsOneWidget);
    expect(find.text('4/40'), findsOneWidget);

    await _chooseRunningPace(tester);
    final paceFrom = _editorField('Ritmo (m:ss/km)');
    final paceTo = _editorField('Hasta (m:ss/km)');
    await _show(tester, paceFrom);
    await tester.enterText(paceFrom, '4:00');
    await tester.enterText(paceTo, '4:30');
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('16 min–18 min'), findsOneWidget);
    expect(
      draftStore.draft?.input.blocks.single.exercises.single.sets,
      hasLength(4),
    );
    expect(draftStore.draft?.input.estimatedDurationMinutes, 17);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una superserie guía A1 y A2 y permite repetir catálogo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _WorkoutRepository();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(_ExerciseRepository()),
      createExercise: CreateExerciseUseCase(_ExerciseRepository()),
      draftStore: _DraftStore(),
      createWorkout: CreatePersonalWorkoutUseCase(repository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
      reviseWorkout: RevisePersonalWorkoutUseCase(repository),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutEditorPage(),
        ),
      ),
    );
    await tester.pump();
    final formatSelector = find.byType(
      DropdownButtonFormField<WorkoutBlockFormat>,
    );
    await _show(tester, formatSelector);
    await _show(tester, formatSelector);
    await tester.tap(formatSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Superserie').last);
    await tester.pumpAndSettle();

    final choose = find.text('Buscar ejercicio del catálogo');
    expect(choose, findsNWidgets(2));
    await _show(tester, choose.first);
    await tester.tap(choose.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dominadas').last);
    await tester.pumpAndSettle();
    await _show(tester, choose);
    await tester.tap(choose);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dominadas').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Cambiar ejercicio · Dominadas'),
      findsNWidgets(2),
    );
    expect(find.text('A1'), findsWidgets);
    expect(find.text('A2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busca y crea un ejercicio propio desde el editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final exerciseRepository = _ExerciseRepository();
    final workoutRepository = _WorkoutRepository();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(exerciseRepository),
      createExercise: CreateExerciseUseCase(exerciseRepository),
      draftStore: _DraftStore(),
      createWorkout: CreatePersonalWorkoutUseCase(workoutRepository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(workoutRepository),
      reviseWorkout: RevisePersonalWorkoutUseCase(workoutRepository),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutEditorPage(),
        ),
      ),
    );
    await tester.pump();

    final addExercise = find.text('Buscar ejercicio del catálogo').first;
    await _show(tester, addExercise);
    await tester.pumpAndSettle();
    await tester.tap(addExercise);
    await tester.pumpAndSettle();

    expect(find.text('Buscar'), findsOneWidget);
    expect(find.text('EntrenaOP'), findsOneWidget);
    expect(find.text('Míos'), findsOneWidget);
    await tester.tap(find.text('Crear ejercicio'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('personal-exercise-name')),
      'Press francés',
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal-exercise-muscles')),
      'tríceps',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('personal-exercise-name')),
          )
          .controller
          ?.text,
      'Press francés',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('personal-exercise-muscles')),
          )
          .controller
          ?.text,
      'tríceps',
    );
    final createAndAdd = find.text('Crear y añadir');
    await _show(tester, createAndAdd);
    await tester.pumpAndSettle();
    await tester.tap(createAndAdd);
    await tester.pumpAndSettle();

    expect(
      cubit.state.exercises.map((item) => item.name),
      contains('Press francés'),
    );
    expect(find.textContaining('Press francés'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cambia un ejercicio desde el buscador sin añadir otra fila', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _WorkoutRepository();
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(_TwoExercisesRepository()),
      createExercise: CreateExerciseUseCase(_TwoExercisesRepository()),
      draftStore: _DraftStore(),
      createWorkout: CreatePersonalWorkoutUseCase(repository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(repository),
      reviseWorkout: RevisePersonalWorkoutUseCase(repository),
    );
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutEditorPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    final addExercise = find.text('Buscar ejercicio del catálogo').first;
    await _show(tester, addExercise);
    await tester.pumpAndSettle();
    await tester.tap(addExercise);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dominadas').last);
    await tester.pumpAndSettle();

    final change = find.textContaining('Cambiar ejercicio · Dominadas');
    await _show(tester, change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar'),
      'Sentadillas',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sentadillas').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Cambiar ejercicio · Sentadillas'),
      findsOneWidget,
    );
    expect(find.text('Dominadas'), findsNothing);
    expect(find.text('Posición 1'), findsOneWidget);
    expect(find.text('Posición 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recupera y vuelve a guardar automáticamente un borrador', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final exerciseRepository = _ExerciseRepository();
    final workoutRepository = _WorkoutRepository();
    final draftStore = _DraftStore()
      ..draft = WorkoutEditorDraftSnapshot(
        savedAt: DateTime(2026, 9, 21, 20, 30),
        input: const CreatePersonalWorkoutInput(
          name: 'Borrador recuperado',
          estimatedDurationMinutes: 35,
          blocks: [
            WorkoutBlockDraft(
              name: 'Principal',
              exercises: [
                WorkoutExerciseDraft(
                  exerciseId: 'exercise-1',
                  sets: [
                    WorkoutSetDraft(
                      targetType: WorkoutTargetType.repetitions,
                      targetValue: 8,
                      restAfterSeconds: 90,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    final cubit = WorkoutEditorCubit(
      getExercises: GetExercisesUseCase(exerciseRepository),
      createExercise: CreateExerciseUseCase(exerciseRepository),
      draftStore: draftStore,
      createWorkout: CreatePersonalWorkoutUseCase(workoutRepository),
      getWorkoutTemplate: GetWorkoutTemplateUseCase(workoutRepository),
      reviseWorkout: RevisePersonalWorkoutUseCase(workoutRepository),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutEditorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Borrador encontrado'), findsOneWidget);
    await tester.tap(find.text('Recuperar'));
    await tester.pumpAndSettle();

    final nameField = find.byKey(const ValueKey('workout-name'));
    expect(
      tester.widget<TextField>(nameField).controller?.text,
      'Borrador recuperado',
    );

    await tester.enterText(nameField, 'Borrador actualizado');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(draftStore.draft?.input.name, 'Borrador actualizado');
    expect(tester.takeException(), isNull);
  });
}

const _input = CreatePersonalWorkoutInput(
  name: 'Mi sesión revisada',
  estimatedDurationMinutes: 30,
  blocks: [
    WorkoutBlockDraft(
      name: 'Principal',
      exercises: [
        WorkoutExerciseDraft(
          exerciseId: 'exercise-1',
          sets: [
            WorkoutSetDraft(
              targetType: WorkoutTargetType.repetitions,
              targetValue: 8,
              restAfterSeconds: 90,
            ),
          ],
        ),
      ],
    ),
  ],
);

class _ExerciseRepository implements ExerciseRepository {
  @override
  Future<List<ExerciseEntity>> getExercises() async => const [
    ExerciseEntity(
      id: 'exercise-1',
      name: 'Dominadas',
      muscleGroups: ['espalda'],
      equipment: ['barra'],
      difficulty: 'media',
      exerciseType: 'repeticiones',
      isPublic: true,
      origin: ExerciseOrigin.system,
    ),
  ];

  @override
  Future<ExerciseEntity> createExercise(
    PersonalExerciseDraft exercise, {
    ExerciseImageUpload? image,
  }) async => ExerciseEntity(
    id: 'exercise-personal',
    name: exercise.name,
    description: exercise.description,
    videoUrl: exercise.videoUrl,
    muscleGroups: exercise.muscleGroups,
    equipment: exercise.equipment,
    difficulty: exercise.difficulty,
    exerciseType: exercise.exerciseType,
    isPublic: false,
    createdBy: 'user-id',
    origin: ExerciseOrigin.user,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TwoExercisesRepository extends _ExerciseRepository {
  @override
  Future<List<ExerciseEntity>> getExercises() async => [
    ...await super.getExercises(),
    const ExerciseEntity(
      id: 'exercise-2',
      name: 'Sentadillas',
      muscleGroups: ['piernas'],
      equipment: [],
      difficulty: 'media',
      exerciseType: 'repeticiones',
      isPublic: true,
      origin: ExerciseOrigin.system,
    ),
  ];
}

class _StrengthCatalogRepository extends _ExerciseRepository {
  @override
  Future<List<ExerciseEntity>> getExercises() async {
    final catalog = StrengthExerciseCatalogCodec.decode(readCatalogJson());
    return [
      for (final profile in catalog.exercises)
        ExerciseEntity(
          id: profile.code,
          name: profile.name,
          muscleGroups: profile.primaryMuscles,
          equipment: profile.requiredEquipment,
          difficulty: 'inicial',
          exerciseType: 'repeticiones',
          isPublic: true,
          origin: ExerciseOrigin.system,
          trainingProfile: profile,
        ),
      const ExerciseEntity(
        id: 'private-pull-up',
        name: 'Dominada prona personal',
        muscleGroups: ['espalda'],
        equipment: ['barra'],
        difficulty: 'intermedio',
        exerciseType: 'repeticiones',
        isPublic: false,
        origin: ExerciseOrigin.user,
        createdBy: 'user-id',
      ),
    ];
  }
}

class _DraftStore implements WorkoutEditorDraftStore {
  WorkoutEditorDraftSnapshot? draft;

  @override
  Future<void> clear(String draftId) async => draft = null;

  @override
  Future<WorkoutEditorDraftSnapshot?> read(String draftId) async => draft;

  @override
  Future<void> write(
    String draftId,
    WorkoutEditorDraftSnapshot snapshot,
  ) async => draft = snapshot;
}

class _WorkoutRepository implements WorkoutRepository {
  String? revisedTemplateId;
  bool denyCreation = false;
  @override
  Future<String> createPersonalTemplate(
    CreatePersonalWorkoutInput input,
  ) async {
    if (denyCreation) throw ProAccessDenied.fromDetails('free_session_limit')!;
    return 'created-template';
  }

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async =>
      const WorkoutTemplate(
        id: 'template-v1',
        name: 'Mi sesión',
        description: 'Descripción',
        estimatedDurationMinutes: 30,
        version: 1,
        blocks: [
          WorkoutBlock(
            id: 'block-1',
            name: 'Sesión',
            format: WorkoutBlockFormat.straightSets,
            rounds: 1,
            restAfterSeconds: 0,
            items: [
              WorkoutItem(
                id: 'item-1',
                exerciseId: 'exercise-1',
                exerciseName: 'Dominadas',
                sets: [
                  WorkoutSet(
                    id: 'set-1',
                    order: 0,
                    targetReps: 6,
                    restAfterSeconds: 90,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  @override
  Future<String> revisePersonalTemplate(
    String templateId,
    CreatePersonalWorkoutInput input,
  ) async {
    revisedTemplateId = templateId;
    return 'template-v2';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _editorField(String label) => find.byWidgetPredicate(
  (w) =>
      w is TextField &&
      (w.key == ValueKey('editor-field-$label') ||
          w.decoration?.labelText == label),
);

Future<void> _show(WidgetTester tester, Finder finder) async {
  bool found() {
    try {
      return finder.evaluate().isNotEmpty;
    } on StateError {
      return false;
    }
  }

  if (!found()) {
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(0);
    await tester.pumpAndSettle();
    for (var i = 0; !found() && i < 80; i++) {
      final next = (position.pixels + 250).clamp(0.0, position.maxScrollExtent);
      if (next == position.pixels) break;
      position.jumpTo(next);
      await tester.pumpAndSettle();
    }
  }
  expect(found(), isTrue, reason: 'Control compartido visible: $finder');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _chooseRunningPace(WidgetTester tester) async {
  final header = find.byKey(const ValueKey('running-step-header-0'));
  final fields = find.byKey(const ValueKey('work-fields-0'));
  if (fields.evaluate().isEmpty) {
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
  }
  final pace = find.descendant(
    of: fields,
    matching: find.widgetWithText(TextFormField, 'Ritmo (m:ss/km)'),
  );
  if (pace.evaluate().isNotEmpty) return;
  final goal = find
      .descendant(
        of: fields,
        matching: find.byType(DropdownButtonFormField<bool>),
      )
      .first;
  await tester.ensureVisible(goal);
  await tester.pumpAndSettle();
  await tester.tap(goal);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ritmo').last);
  await tester.pumpAndSettle();
}

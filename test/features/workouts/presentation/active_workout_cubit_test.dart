import 'dart:convert';
import 'dart:io';

import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercise_by_id_usecase.dart';
import 'package:entrenaop/features/exercises/presentation/widgets/exercise_detail_sheet.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_amrap_draft_store.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_amrap_sequence.dart';

import '../../../helpers/workout_amrap_fixture.dart';

import 'package:entrenaop/features/workouts/presentation/widgets/workout_amrap_review.dart';

import '../../../helpers/performance_visual_review.dart';
import '../../../helpers/review_image_http_client.dart';

import 'package:entrenaop/features/workouts/domain/services/workout_session_draft_store.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_effort_field.dart';

import '../../../helpers/memory_workout_session_draft_store.dart';
import '../../../helpers/memory_workout_amrap_draft_store.dart';

import 'dart:async';

import 'package:entrenaop/core/navigation/app_back_gesture.dart';
import 'package:entrenaop/core/router/material_app_route.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';

import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/services/phone_running.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_lock_screen.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_state.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/phone_run_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/active_workout_page.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_history_detail_page.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/phone_run_panel.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_set_countdown.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_tabata_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';

void main() {
  testWidgets(
    'fuerza conserva el descanso al volver de otra app y avanza si venció',
    (tester) async {
      const screen = MethodChannel('es.entrenaop/clock_screen');
      final messenger = tester.binding.defaultBinaryMessenger;
      final wakeChanges = <bool>[];
      messenger.setMockMethodCallHandler(screen, (call) async {
        wakeChanges.add(call.arguments as bool);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(screen, null));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final lockScreen = _LockScreen();
      var now = DateTime.now().toUtc();
      final (cubit, _) = await _mountSession(
        tester,
        _Repository()
          ..execution = _execution(format: WorkoutBlockFormat.straightSets),
        lockScreen: lockScreen,
        now: () => now,
      );
      await tester.tap(find.byTooltip('Opciones de sesión'));
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(find.text('Mantener pantalla encendida')),
      );
      await tester.pumpAndSettle();
      expect(wakeChanges.last, isTrue);
      await cubit.completeCurrentSet(
        const WorkoutSetResultInput(resultId: 'set-1', actualReps: 8),
        restSecondsOverride: 30,
      );
      await tester.pump();
      final deadline = now.add(const Duration(seconds: 30));
      expect(lockScreen.visible?.restEndsAt, deadline);
      expect(
        lockScreen.visible?.exercise,
        cubit.state.execution!.currentSet!.exerciseName,
      );
      final shown = lockScreen.shown;
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(cubit.state.restSecondsRemaining, 25);
      expect(lockScreen.shown, shown);
      await tester.tap(find.byTooltip('Añadir 10 segundos'));
      await tester.pump();
      expect(cubit.state.restSecondsRemaining, 35);
      expect(
        lockScreen.visible?.restEndsAt,
        deadline.add(const Duration(seconds: 10)),
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Saltar descanso'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byTooltip('Quitar 10 segundos'));
      await tester.pump();
      expect(cubit.state.restSecondsRemaining, 25);

      void enterBackground() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }

      void returnToWorkout() {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }

      enterBackground();
      expect(wakeChanges.last, isFalse);
      expect(lockScreen.visible?.restEndsAt, deadline);
      now = now.add(const Duration(seconds: 12));
      returnToWorkout();
      expect(cubit.state.status, ActiveWorkoutStatus.resting);
      expect(cubit.state.restSecondsRemaining, 13);
      expect(lockScreen.visible?.restEndsAt, deadline);

      enterBackground();
      now = now.add(const Duration(seconds: 14));
      returnToWorkout();
      await tester.pumpAndSettle();
      expect(wakeChanges.last, isTrue);
      expect(cubit.state.status, ActiveWorkoutStatus.ready);
      expect(cubit.state.execution!.currentSet!.id, 'set-2');
      expect(lockScreen.visible?.restEndsAt, isNull);
      await tester.pumpWidget(const SizedBox());
      expect(wakeChanges.last, isFalse);
      expect(lockScreen.visible, isNull);
    },
  );

  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'Farmer carry registra metros y carga a $width px, texto ×$scale',
      (tester) async {
        tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const carry = WorkoutExecutionSet(
          id: 'carry',
          blockOrder: 0,
          blockName: 'Trabajo principal',
          itemOrder: 0,
          exerciseId: 'farmer-carry',
          exerciseName: 'Farmer carry',
          setOrder: 0,
          targetDistanceMeters: 30,
          targetLoadKg: 24,
          restAfterSeconds: 0,
          status: WorkoutSetStatus.pending,
        );
        final repository = _Repository()
          ..execution = _execution(templateName: 'Fuerza')
              .copyWith(sets: [carry]);
        final (cubit, _) = await _mountSession(
          tester,
          repository,
          textScaler: TextScaler.linear(scale),
        );

        final metres = find.widgetWithText(TextFormField, 'Metros realizados');
        final load = find.widgetWithText(TextFormField, 'Carga (kg)');
        expect(find.text('Objetivo · 30 metros'), findsOneWidget);
        expect(find.text('24 kg'), findsOneWidget);
        expect(find.text('Repeticiones realizadas'), findsNothing);
        expect(find.text('Tiempo realizado'), findsNothing);
        if (width == 320) {
          await Scrollable.ensureVisible(
            tester.element(metres),
            alignment: .03,
          );
        }
        await tester.pumpAndSettle();
        expect(metres.hitTestable(), findsOneWidget);
        expect(load.hitTestable(), findsOneWidget);
        await capturePerformanceWidget(
          tester,
          'farmer-carry-registro-${width.toInt()}',
        );
        await tester.ensureVisible(metres);
        await tester.enterText(metres, '27');
        tester.view.viewInsets = FakeViewPadding(
          bottom: width == 320 ? 220 : 300,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(load);
        await tester.pumpAndSettle();
        expect(load.hitTestable(), findsOneWidget);
        await tester.enterText(load, '22,5');
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();

        expect(find.text('Terminar serie').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Terminar serie'));
        await tester.pumpAndSettle();
        expect(find.text('Revisar series'), findsNothing);
        final records = find.text('Series y registros');
        await tester.ensureVisible(records);
        await tester.tap(records);
        await tester.pumpAndSettle();
        final inlineMetres = _inlineCell('carry', 'distance');
        await tester.ensureVisible(inlineMetres);
        expect(_inlineValue('carry', 'distance', '27'), findsOneWidget);
        await capturePerformanceWidget(
          tester,
          'farmer-carry-confirmacion-${width.toInt()}',
        );
        expect(find.byTooltip('Confirmar Serie 1'), findsNothing);
        expect(_inlineValue('carry', 'load', '22,5'), findsOneWidget);
        await tester.ensureVisible(find.text('Registrada'));
        expect(find.text('Registrada').hitTestable(), findsOneWidget);
        await tester.tap(find.byTooltip('Cerrar registros'));
        await tester.pumpAndSettle();
        expect(find.text('Finalizar sesión'), findsOneWidget);
        await cubit.finish(finalRpe: 6);
        expect(repository.lastSetResult?.actualDistanceMeters, 27);
        expect(repository.lastSetResult?.actualLoadKg, 22.5);
        expect(repository.lastSetResult?.actualReps, isNull);
        expect(repository.lastSetResult?.actualDurationSeconds, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'un parcial del guiado pasa al registro manual sin confirmar otras series',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final location = _RunLocation();
      addTearDown(location.events.close);
      final repository = _Repository()
        ..execution = _execution(templateName: 'Series de prueba').copyWith(
          sets: [
            _phoneRunSet,
            const WorkoutExecutionSet(
              id: 'run-2',
              blockOrder: 0,
              blockName: 'Series',
              blockFormat: WorkoutBlockFormat.running,
              itemOrder: 0,
              exerciseId: runningExerciseId,
              exerciseName: 'Carrera',
              setOrder: 1,
              targetDistanceMeters: 400,
              restAfterSeconds: 0,
              status: WorkoutSetStatus.pending,
            ),
          ],
        );
      final (active, _) = await _mountSession(
        tester,
        repository,
        createPhoneRun: (id) => PhoneRunCubit(
          executionId: id,
          location: location,
          checkpoints: _MemoryRunCheckpoints(),
          now: tester.binding.clock.now,
        ),
      );
      await tester.tap(find.text('Entrenar con el móvil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empezar entrenamiento'));
      await tester.pumpAndSettle();
      location.fix(tester.binding.clock.now(), 0);
      await tester.pump(const Duration(seconds: 8));
      location.fix(tester.binding.clock.now(), 0.0003);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar vuelta'));
      await tester.pumpAndSettle();
      expect(find.text('0 / 400 m'), findsOneWidget);
      final manual = find.text('Volver al registro manual');
      await tester.scrollUntilVisible(
        manual,
        100,
        scrollable: find.descendant(
          of: find.byType(PhoneRunPanel),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(manual);
      await tester.pumpAndSettle();

      final draft = active.state.drafts[_phoneRunSet.id];
      expect(draft?.endedAt, isNotNull);
      expect(draft?.confirmed, isFalse);
      expect(draft?.result.actualDistanceMeters, closeTo(33, 1));
      expect(active.state.execution?.currentSet?.id, 'run-2');
      expect(active.state.drafts['run-2'], isNull);
      expect(location.stops, location.starts);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (size, textScale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 480), 2.0),
  ]) {
    testWidgets(
      'grabar un rodaje es la acción principal junto al objetivo: $size, texto $textScale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final location = _RunLocation();
        final repository = _Repository()
          ..execution = _execution(
            allowUnrecorded: true,
            templateName: 'Rodaje de prueba GPS · 400 m',
          ).copyWith(sets: [_phoneRunSet]);
        await _mountSession(
          tester,
          repository,
          textScaler: TextScaler.linear(textScale),
          createPhoneRun: (id) => PhoneRunCubit(
            executionId: id,
            location: location,
            checkpoints: _EmptyRunCheckpoints(),
          ),
        );
        final record = find.widgetWithText(FilledButton, 'Grabar con el móvil');
        final objective = find.textContaining('Objetivo ·');
        final timer = find.text('Iniciar temporizador');
        expect(
          tester.getRect(record).top,
          greaterThan(tester.getRect(objective).bottom),
        );
        expect(
          tester.getRect(record).bottom,
          lessThan(tester.getRect(timer).top),
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Terminar serie'),
          findsOneWidget,
        );
        expect(find.text('Empezar con el móvil'), findsNothing);
        expect(find.text('Terminar sin registrar todo'), findsNothing);
        expect(location.starts, isEmpty);
        if (textScale == 1) {
          expect(record.hitTestable(), findsOneWidget);
          await capturePerformanceWidget(tester, 'rodaje-accion-gps');
        }
        await Scrollable.ensureVisible(tester.element(record), alignment: .5);
        await tester.pumpAndSettle();
        expect(record.hitTestable(), findsOneWidget);
        await tester.tap(record);
        await tester.pumpAndSettle();
        expect(location.starts, hasLength(1));
        expect(find.text('Buscando señal GPS…'), findsOneWidget);

        final manual = find.text('Volver al registro manual');
        await tester.scrollUntilVisible(
          manual,
          120,
          scrollable: find.descendant(
            of: find.byType(PhoneRunPanel),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(manual);
        await tester.pumpAndSettle();
        expect(location.stops, location.starts);
        expect(timer, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }

  for (final partial in [false, true]) {
    testWidgets(
      'cerrar desde la salida conserva datos y permite volver: parcial=$partial',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repository = _Repository()
          ..execution = _executionWithStatuses([
            partial ? WorkoutSetStatus.completed : WorkoutSetStatus.pending,
            WorkoutSetStatus.pending,
          ], allowUnrecorded: true);
        final before = repository.execution.sets;
        final (cubit, router) = await _mountSession(tester, repository);
        expect(find.text('Terminar sin registrar todo'), findsNothing);
        await _chooseExitPartialCompletion(tester);
        await capturePerformanceWidget(
          tester,
          'confirmar-cierre-opcional-$partial-390',
        );
        await tester.tap(find.text('Seguir entrenando'));
        await tester.pumpAndSettle();
        expect(repository.unrecordedFinishAttempts, 0);
        expect(router.state.matchedLocation, '/session');
        expect(find.text('Terminar sin registrar todo'), findsNothing);
        await _chooseExitPartialCompletion(tester);
        await tester.tap(find.text('Terminar sesión'));
        await tester.pumpAndSettle();
        expect(repository.unrecordedFinishAttempts, 1);
        expect(repository.abandonAttempts, 0);
        expect(repository.finishAttempts, 0);
        expect(cubit.state.status, ActiveWorkoutStatus.completed);
        expect(cubit.state.execution!.completedWithoutFullRecording, isTrue);
        expect(cubit.state.execution!.sets, before);
        expect(cubit.state.execution!.finalRpe, isNull);
        expect(router.state.matchedLocation, '/');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('el cierre sin registros se adapta a 320 px y texto grande', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Repository()
      ..execution = _execution(allowUnrecorded: true);
    final (_, router) = await _mountSession(
      tester,
      repository,
      textScaler: TextScaler.linear(2),
    );
    await _chooseExitPartialCompletion(tester);
    await tester.ensureVisible(find.text('Terminar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminar sesión'));
    await tester.pumpAndSettle();
    expect(repository.unrecordedFinishAttempts, 1);
    expect(router.state.matchedLocation, '/');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin permiso de programa conserva el cierre normal', (
    tester,
  ) async {
    final repository = _Repository();
    final (cubit, _) = await _mountSession(tester, repository);
    await tester.tap(find.byTooltip('Salir de la sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir de la sesión?'), findsOneWidget);
    expect(find.text('Terminar sin registrar todo'), findsNothing);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await cubit.finishWithoutFullRecording();
    await cubit.finish(finalRpe: 5);
    expect(repository.unrecordedFinishAttempts, 0);
    expect(repository.finishAttempts, 0);
    expect(cubit.state.execution!.status, WorkoutExecutionStatus.inProgress);
  });

  test(
    'el cierre sin registros encolado no se reabre por un fallo posterior',
    () async {
      final repository = _Repository()
        ..execution = _execution(allowUnrecorded: true)
        ..unrecordedDisposition = WorkoutMutationDisposition.queued
        ..failPendingAfterFinish = true;
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.finishWithoutFullRecording();
      expect(cubit.state.status, ActiveWorkoutStatus.completed);
      expect(cubit.state.pendingSyncCount, 1);
      expect(
        cubit.state.execution!.sets.every(
          (s) => s.status == WorkoutSetStatus.pending,
        ),
        isTrue,
      );
      await cubit.finishWithoutFullRecording();
      expect(repository.unrecordedFinishAttempts, 1);
    },
  );

  testWidgets(
    'termina aunque solo queden borradores y permite confirmar desde historial',
    (tester) async {
      final repository = _Repository()
        ..execution = _execution(
          allowUnrecorded: true,
          format: WorkoutBlockFormat.straightSets,
        );
      final drafts = MemoryWorkoutSessionDraftStore();
      final (cubit, _) = await _mountSession(
        tester,
        repository,
        sessionDraftStore: drafts,
      );
      await cubit.updateDraft(
        const WorkoutSetResultInput(resultId: 'set-1', actualReps: 6),
        {'reps': '6'},
      );
      await cubit.endCurrentSet(startRest: false);
      await cubit.endCurrentSet(startRest: false);
      expect(cubit.state.execution!.currentSet, isNull);
      await tester.pumpAndSettle();
      expect(find.text('Revisar series'), findsOneWidget);
      await tester.ensureVisible(find.text('Finalizar con registro parcial'));
      await tester.tap(find.text('Finalizar con registro parcial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminar sesión'));
      await tester.pumpAndSettle();
      expect(repository.unrecordedFinishAttempts, 1);
      expect(cubit.state.status, ActiveWorkoutStatus.completed);
      expect(
        cubit.state.execution!.sets.first.status,
        WorkoutSetStatus.pending,
      );
      expect(
        (await drafts.read(cubit.executionId))['set-1']!.result.actualReps,
        6,
      );
      final history = WorkoutHistoryDetailCubit(
        executionId: cubit.executionId,
        getExecution: GetWorkoutExecutionUseCase(repository),
        correctSet: CorrectWorkoutSetUseCase(repository),
        completeSet: CompleteWorkoutSetUseCase(repository),
        draftStore: drafts,
      );
      addTearDown(history.close);
      await history.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: BlocProvider.value(
            value: history,
            child: WorkoutHistoryDetailPage(
              timerStore: _TimerStore(),
              cueService: _CueService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completar registros pendientes'));
      await tester.pumpAndSettle();
      final pending = find.textContaining(
        'Serie 1 · Realizada · datos por confirmar',
      );
      await tester.ensureVisible(pending);
      await tester.tap(pending);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '6'), findsOneWidget);
      await tester.ensureVisible(find.text('Confirmar datos'));
      await tester.tap(find.text('Confirmar datos'));
      await tester.pumpAndSettle();
      expect(history.state.execution!.sets.first.actualReps, 6);
      expect(
        (await drafts.read(cubit.executionId)).containsKey('set-1'),
        isFalse,
      );
      expect(
        (await drafts.read(cubit.executionId)).containsKey('set-2'),
        isTrue,
      );
    },
  );

  testWidgets(
    'el cierre sin registrar todo funciona con el botón Atrás del sistema',
    (tester) async {
      final repository = _Repository()
        ..execution = _execution(allowUnrecorded: true);
      final (_, router) = await _mountSession(tester, repository);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Terminar sin registrar todo'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminar sesión'));
      await tester.pumpAndSettle();
      expect(repository.unrecordedFinishAttempts, 1);
      expect(router.state.matchedLocation, '/');
      expect(tester.takeException(), isNull);
    },
  );

  test('conserva el borrador AMRAP antes del cierre sin registro', () async {
    final repository = _Repository()
      ..execution = _amrapExecution(allowUnrecorded: true);
    final drafts = MemoryWorkoutAmrapDraftStore();
    final cubit = _cubit(repository, amrapDraftStore: drafts);
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.changeAmrapRounds(0, 1);
    await cubit.finishWithoutFullRecording();
    expect(repository.unrecordedFinishAttempts, 1);
    expect(cubit.state.status, ActiveWorkoutStatus.completed);
    expect((await drafts.read(cubit.executionId))[0]!.rounds, '1');
  });

  test('un fallo de cierre conserva la sesión y permite reintentar', () async {
    final repository = _Repository()
      ..execution = _execution(allowUnrecorded: true)
      ..failFinish = true;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.finishWithoutFullRecording();
    expect(cubit.state.status, ActiveWorkoutStatus.failure);
    expect(cubit.state.execution!.status, WorkoutExecutionStatus.inProgress);
    repository.failFinish = false;
    await cubit.finishWithoutFullRecording();
    expect(cubit.state.status, ActiveWorkoutStatus.completed);
    expect(repository.unrecordedFinishAttempts, 2);
  });

  testWidgets('el descanso no reabre ni duplica un cierre en curso', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = _Repository()
      ..execution = _execution(allowUnrecorded: true)
      ..unrecordedGate = gate;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.completeCurrentSet(
      const WorkoutSetResultInput(resultId: 'set-1', actualReps: 6),
    );
    expect(cubit.state.status, ActiveWorkoutStatus.resting);
    final finishing = cubit.finishWithoutFullRecording();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(cubit.state.status, ActiveWorkoutStatus.saving);
    await cubit.finishWithoutFullRecording();
    gate.complete();
    await finishing;
    expect(repository.unrecordedFinishAttempts, 1);
    expect(cubit.state.status, ActiveWorkoutStatus.completed);
  });

  testWidgets(
    'completar datos en descanso abre directamente la última serie terminada',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _Repository()
        ..execution = _execution().copyWith(
          sets: [
            for (var i = 0; i < 16; i++)
              WorkoutExecutionSet(
                id: 'long-$i',
                blockOrder: i,
                blockName: 'Bloque $i',
                itemOrder: 0,
                exerciseId: 'exercise-$i',
                exerciseName: 'Ejercicio $i',
                setOrder: 0,
                targetReps: 8,
                restAfterSeconds: 60,
                status: i < 14
                    ? WorkoutSetStatus.completed
                    : WorkoutSetStatus.pending,
                actualReps: i < 14 ? 8 : null,
              ),
          ],
        );
      final (cubit, _) = await _mountSession(tester, repository);
      await tester.tap(find.text('Terminar serie'));
      await tester.pumpAndSettle();
      final rest = cubit.state.restSecondsRemaining;
      await tester.tap(find.textContaining('Series y registros').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Datos por confirmar').hitTestable(),
        findsOneWidget,
      );
      await capturePerformanceWidget(tester, 'series-pendiente-390');
      await tester.tap(find.byTooltip('Cerrar registros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completar datos de la serie'));
      await tester.pumpAndSettle();
      expect(find.text('Ejercicio 14'), findsOneWidget);
      expect(find.byTooltip('Confirmar Serie 1').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Cerrar registros'), findsOneWidget);
      expect(find.byTooltip('Cerrar resultado'), findsNothing);
      await capturePerformanceWidget(tester, 'serie-completar-directo-390');
      await _enterInlineText(tester, 'long-14', 'reps', '9');
      await tester.pumpAndSettle();
      expect(cubit.state.unconfirmedDraftCount, 0);
      expect(cubit.state.drafts['long-14']?.result.actualReps, 9);
      expect(repository.lastSetResult, isNull);
      expect(cubit.state.status, ActiveWorkoutStatus.resting);
      expect(cubit.state.restSecondsRemaining, lessThanOrEqualTo(rest));
      expect(find.byTooltip('Confirmar Serie 1'), findsNothing);
      await tester.tap(find.byTooltip('Cerrar registros'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      cubit.skipRest();
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('Tabata avanza con borradores de tiempo sin confirmar ni inventar carga o esfuerzo', () async {
    final repository = _Repository()..execution = _tabataExecution();
    final store = MemoryWorkoutSessionDraftStore();
    final cubit = _cubit(repository, sessionDraftStore: store);
    addTearDown(cubit.close);
    await cubit.load();
    for (var i = 0; i < 8; i++) {
      expect(await cubit.endTabataInterval('tabata-$i'), isTrue);
      expect(cubit.state.status, ActiveWorkoutStatus.ready);
    }
    expect(cubit.state.execution!.currentSet, isNull);
    expect(cubit.state.unconfirmedDraftCount, 8);
    expect(repository.lastSetResult, isNull);
    final drafts = await store.read('execution-1');
    expect(drafts.length, 8);
    for (final draft in drafts.values) {
      expect(draft.result.actualDurationSeconds, 20);
      expect(draft.result.actualRpe, isNull);
      expect(draft.result.actualLoadKg, isNull);
      expect(draft.fields['duration'], '0:20');
      expect(draft.confirmed, isFalse);
    }
    await cubit.finish(finalRpe: 5);
    expect(repository.finishAttempts, 0);
  });

  test(
    'Tabata rechaza callbacks antiguos y no avanza si falla el guardado local',
    () async {
      final repository = _Repository()..execution = _tabataExecution();
      final store = _FailingTabataDraftStore();
      final cubit = _cubit(repository, sessionDraftStore: store);
      addTearDown(cubit.close);
      await cubit.load();
      expect(await cubit.endTabataInterval('tabata-1'), isFalse);
      expect(await cubit.endTabataInterval('tabata-0'), isFalse);
      expect(cubit.state.execution!.currentSet!.id, 'tabata-0');
      expect(cubit.state.errorMessage, isNotNull);
      store.failWrite = false;
      expect(await cubit.endTabataInterval('tabata-0'), isTrue);
      expect(await cubit.endTabataInterval('tabata-0'), isFalse);
      expect(cubit.state.execution!.currentSet!.id, 'tabata-1');
    },
  );

  testWidgets('el ejecutor selecciona un único reloj para todo el Tabata', (
    tester,
  ) async {
    final tabata = _tabataExecution();
    final repository = _Repository()
      ..execution = tabata.copyWith(
        sets: [
          ...tabata.sets,
          const WorkoutExecutionSet(
            id: 'next-emom',
            blockOrder: 1,
            blockName: 'EMOM',
            blockFormat: WorkoutBlockFormat.emom,
            itemOrder: 0,
            exerciseId: 'exercise-1',
            exerciseName: 'Sentadillas',
            setOrder: 0,
            targetReps: 8,
            restAfterSeconds: 60,
            status: WorkoutSetStatus.pending,
          ),
        ],
      );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: ActiveWorkoutPage(
            timerStore: _TimerStore(),
            cueService: _CueService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutTabataEntry), findsOneWidget);
    expect(find.byType(WorkoutSetCountdown), findsNothing);
    expect(find.text('Iniciar Tabata'), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      await cubit.endTabataInterval('tabata-$i');
      await tester.pump();
    }
    // Resolver las series no desmonta el cierre del bloque ni abre el siguiente.
    expect(cubit.state.execution!.currentSet!.id, 'next-emom');
    expect(find.byType(WorkoutTabataEntry), findsOneWidget);
    expect(find.byType(WorkoutSetCountdown), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  // Estas regresiones miden tarjetas completas en dispositivos; Ahem tiene
  // métricas distintas a las fuentes de la aplicación.
  setUpAll(() => loadReviewFont(always: true));
  for (final failure in ['read', 'pending', 'clear', 'rejected']) {
    test(
      'cierre EMOM ante fallo $failure no confunde guardado y limpieza',
      () async {
        final repository = _Repository();
        repository.execution = repository.execution.copyWith(
          sets: repository.execution.sets
              .map((s) => s.copyWith(status: WorkoutSetStatus.completed))
              .toList(),
        );
        final store = _FailingClearDraftStore();
        final cubit = _cubit(repository, sessionDraftStore: store);
        addTearDown(cubit.close);
        await cubit.load();
        repository.failReadAfterFinish = failure == 'read';
        repository.failPendingAfterFinish = failure == 'pending';
        repository.failFinish = failure == 'rejected';
        store.failClear = failure == 'clear';
        await cubit.finish(finalRpe: 6);
        if (failure == 'rejected') {
          expect(cubit.state.status, ActiveWorkoutStatus.failure);
          expect(
            repository.execution.status,
            WorkoutExecutionStatus.inProgress,
          );
          return;
        }
        expect(cubit.state.status, ActiveWorkoutStatus.completed);
        expect(cubit.state.execution!.status, WorkoutExecutionStatus.completed);
        expect(cubit.state.execution!.finalRpe, 6);
        await cubit.finish(finalRpe: 8);
        expect(repository.finishAttempts, 1);
        repository.failReadAfterFinish = false;
        repository.failPendingAfterFinish = false;
        final reopened = _cubit(repository);
        addTearDown(reopened.close);
        await reopened.load();
        expect(reopened.state.status, ActiveWorkoutStatus.completed);
      },
    );
  }
  testWidgets('Continuar encabeza la salida y conserva la sesión activa', (
    tester,
  ) async {
    final repository = _Repository();
    final (cubit, router) = await _mountSession(tester, repository);
    final execution = cubit.state.execution;
    await tester.tap(find.byTooltip('Salir de la sesión'));
    await tester.pumpAndSettle();
    final continueButton = find.widgetWithText(FilledButton, 'Continuar');
    final resume = find.widgetWithText(
      OutlinedButton,
      'Salir y retomar después',
    );
    final close = find.widgetWithText(
      OutlinedButton,
      'Finalizar y conservar lo realizado',
    );
    final discard = find.widgetWithText(OutlinedButton, 'Descartar sesión');
    expect(
      tester.getTopLeft(continueButton).dy,
      lessThan(tester.getTopLeft(resume).dy),
    );
    expect(tester.getTopLeft(resume).dy, lessThan(tester.getTopLeft(close).dy));
    expect(
      tester.getTopLeft(close).dy,
      lessThan(tester.getTopLeft(discard).dy),
    );
    expect(tester.getSize(continueButton).width, tester.getSize(resume).width);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/session');
    expect(cubit.state.execution, execution);
    expect(repository.discardAttempts, 0);
    expect(repository.abandonAttempts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'terminar inicia descanso sin inventar datos y confirmar no lo reinicia',
    (tester) async {
      final repository = _Repository();
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.endCurrentSet();
      expect(cubit.state.status, ActiveWorkoutStatus.resting);
      expect(cubit.state.execution!.currentSet!.id, 'set-2');
      expect(repository.lastSetResult, isNull);
      expect(cubit.state.unconfirmedDraftCount, 1);
      await tester.pump(const Duration(seconds: 8));
      final remaining = cubit.state.restSecondsRemaining;
      expect(
        await cubit.confirmDraft(
          const WorkoutSetResultInput(resultId: 'set-1'),
          const {},
        ),
        false,
      );
      expect(repository.lastSetResult, isNull);
      expect(
        await cubit.confirmDraft(
          const WorkoutSetResultInput(
            resultId: 'set-1',
            actualReps: 6,
            actualRir: 0,
          ),
          const {'reps': '6'},
        ),
        true,
      );
      expect(repository.lastSetResult!.actualReps, 6);
      expect(repository.lastSetResult!.actualRir, 0);
      expect(cubit.state.restSecondsRemaining, remaining);
      expect(cubit.state.status, ActiveWorkoutStatus.resting);
      expect(cubit.state.unconfirmedDraftCount, 0);
      await tester.pump(const Duration(seconds: 61));
    },
  );

  testWidgets(
    'retomar recupera series pendientes y el descanso del dispositivo',
    (tester) async {
      final repository = _Repository();
      final store = MemoryWorkoutSessionDraftStore();
      final timerStore = _TimerStore();
      final first = _cubit(
        repository,
        sessionDraftStore: store,
        timerStore: timerStore,
      );
      await first.load();
      await first.updateDraft(
        const WorkoutSetResultInput(resultId: 'set-1', actualReps: 5),
        const {'reps': '5', 'duration': ''},
      );
      await first.endCurrentSet();
      await first.close();
      final second = _cubit(
        repository,
        sessionDraftStore: store,
        timerStore: timerStore,
      );
      addTearDown(second.close);
      await second.load();
      expect(second.state.status, ActiveWorkoutStatus.resting);
      expect(second.state.execution!.currentSet!.id, 'set-2');
      expect(second.state.drafts['set-1']!.fields['reps'], '5');
      expect(second.state.unconfirmedDraftCount, 1);
      expect(repository.lastSetResult, isNull);
      await tester.pump(const Duration(seconds: 61));
    },
  );

  testWidgets(
    'los retoques se consolidan una vez y borrar esfuerzo conserva ausencia',
    (tester) async {
      final repository = _Repository();
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.endCurrentSet();
      await cubit.confirmDraft(
        const WorkoutSetResultInput(
          resultId: 'set-1',
          actualReps: 8,
          actualRir: 3,
        ),
        const {'reps': '8'},
      );
      for (final reps in [7, 6, 5, 4]) {
        final result = WorkoutSetResultInput(
          resultId: 'set-1',
          actualReps: reps,
        );
        await cubit.updateDraft(result, {'reps': '$reps'});
        await cubit.confirmDraft(result, {'reps': '$reps'});
      }
      expect(repository.correctionCount, 0);
      expect(cubit.state.execution!.sets.first.actualRir, isNull);
      await tester.pump(const Duration(seconds: 61));
      await cubit.skipCurrentSet();
      repository.failCorrection = true;
      await cubit.finish(finalRpe: 6);
      expect(cubit.state.status, ActiveWorkoutStatus.failure);
      expect(cubit.state.drafts['set-1']!.result.actualReps, 4);
      repository.failCorrection = false;
      await cubit.finish(finalRpe: 6);
      expect(cubit.state.status, ActiveWorkoutStatus.completed);
      expect(repository.correctionCount, 1);
      expect(repository.execution.sets.first.actualReps, 4);
      expect(repository.execution.sets.first.actualRir, isNull);
      await tester.pump(const Duration(seconds: 61));
    },
  );

  testWidgets('al volver a la app respeta el descarte del servidor', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final repository = _Repository();
    final (cubit, _) = await _mountSession(tester, repository);
    await cubit.endCurrentSet();
    await tester.pump();
    expect(cubit.state.unconfirmedDraftCount, 1);

    Future<void> resume() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    repository.failExecutionRead = true;
    await resume();
    expect(cubit.state.unconfirmedDraftCount, 1);
    expect(cubit.state.status, ActiveWorkoutStatus.resting);

    repository.failExecutionRead = false;
    repository.executionMissing = true;
    await resume();
    expect(cubit.state.status, ActiveWorkoutStatus.discarded);
    expect(cubit.state.unconfirmedDraftCount, 0);
    expect(repository.discardAttempts, 0);
    expect(find.text('Sesión descartada'), findsOneWidget);
    expect(find.text('Volver'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final prescribedLoad in [null, 120.0]) {
    testWidgets('carga real opcional con pauta de $prescribedLoad kg', (
      tester,
    ) async {
      final repository = _Repository()
        ..execution = _execution().copyWith(
          sets: [
            WorkoutExecutionSet(
              id: 'set-1',
              blockOrder: 0,
              blockName: 'Fuerza',
              itemOrder: 0,
              exerciseId: 'exercise-1',
              exerciseName: 'Hip thrust',
              setOrder: 0,
              targetReps: 8,
              targetRir: 3,
              targetLoadKg: prescribedLoad,
              restAfterSeconds: 0,
              status: WorkoutSetStatus.pending,
            ),
          ],
        );
      await _mountSession(tester, repository);
      await _openCurrentResult(tester);
      final field = await _focusInlineField(tester, 'set-1', 'load');
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      if (prescribedLoad == null) await tester.enterText(field, '47,5');
      await _confirmOpenResult(tester);
      expect(repository.lastSetResult, isNotNull);
      expect(
        repository.lastSetResult!.actualLoadKg,
        prescribedLoad == null ? 47.5 : null,
      );
      expect(repository.lastSetResult!.actualRir, isNull);
    });
  }

  testWidgets('no permite finalizar con resultados sin confirmar', (
    tester,
  ) async {
    final repository = _Repository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.endCurrentSet();
    await tester.pump(const Duration(seconds: 61));
    await cubit.endCurrentSet();
    expect(cubit.state.execution!.currentSet, isNull);
    await cubit.finish(finalRpe: 6);
    expect(cubit.state.status, isNot(ActiveWorkoutStatus.completed));
    expect(repository.execution.status, WorkoutExecutionStatus.inProgress);
    expect(cubit.state.unconfirmedDraftCount, 2);
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets(
    'editar durante descanso conserva los campos al llegar a cero y no edita el ejercicio',
    (tester) async {
      final repository = _Repository();
      final (cubit, _) = await _mountSession(tester, repository);
      await tester.tap(find.byTooltip('Técnica del ejercicio'));
      await tester.pumpAndSettle();
      expect(find.text('Editar ejercicio'), findsNothing);
      expect(find.text('¿Salir de la sesión?'), findsNothing);
      await tester.tap(find.byTooltip('Cerrar detalle'));
      await tester.pumpAndSettle();
      await _openCurrentResult(tester);
      final field = find.descendant(
        of: find.byKey(const ValueKey('review-set-1')),
        matching: find.widgetWithText(TextFormField, 'Repeticiones realizadas'),
      );
      await tester.enterText(field, '6');
      await tester.pump(const Duration(seconds: 61));
      expect(tester.widget<TextFormField>(field).controller!.text, '6');
      expect(find.text('Revisar resultado'), findsOneWidget);
      expect(cubit.state.drafts['set-1']!.result.actualReps, 6);
      await _confirmOpenResult(tester);
      expect(repository.lastSetResult!.actualReps, 6);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mezclar registro diferido y directo no crea un descanso tras la última serie',
    (tester) async {
      final repository = _Repository();
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.endCurrentSet();
      await tester.pump(const Duration(seconds: 61));
      await cubit.completeCurrentSet(
        const WorkoutSetResultInput(resultId: 'set-2', actualReps: 8),
      );
      expect(cubit.state.execution!.currentSet, isNull);
      expect(cubit.state.status, ActiveWorkoutStatus.ready);
      await tester.pump(const Duration(seconds: 61));
      expect(cubit.state.status, ActiveWorkoutStatus.ready);
      expect(cubit.state.unconfirmedDraftCount, 1);
    },
  );

  testWidgets(
    'un descarte pendiente no permite otra mutación ni pierde el descanso si falla',
    (tester) async {
      final repository = _Repository();
      final response = Completer<void>();
      repository.discardResponse = () => response.future;
      final store = _TimerStore();
      final cubit = _cubit(repository, timerStore: store);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.completeCurrentSet(
        const WorkoutSetResultInput(resultId: 'set-1', actualReps: 8),
      );
      expect(cubit.state.status, ActiveWorkoutStatus.resting);
      final pending = cubit.discard();
      await tester.pump(const Duration(seconds: 3));
      expect(cubit.state.status, ActiveWorkoutStatus.saving);
      expect(await cubit.discard(), false);
      await cubit.completeCurrentSet(
        const WorkoutSetResultInput(resultId: 'set-2', actualReps: 9),
      );
      await cubit.skipCurrentSet();
      await cubit.abandon(WorkoutAbandonmentReason.lackOfTime);
      await cubit.finish(finalRpe: 6);
      expect(cubit.state.status, ActiveWorkoutStatus.saving);
      expect(repository.lastSetResult!.resultId, 'set-1');
      expect(repository.abandonAttempts, 0);
      response.completeError(StateError('Sin conexión'));
      expect(await pending, false);
      expect(cubit.state.status, ActiveWorkoutStatus.resting);
      expect(cubit.state.execution!.completedSetCount, 1);
      expect(store.snapshot, isNotNull);
      repository.discardResponse = null;
      expect(await cubit.discard(), true);
      expect(store.snapshot, isNull);
      await tester.pump(const Duration(seconds: 61));
      expect(cubit.state.status, ActiveWorkoutStatus.discarded);
    },
  );
  for (final statuses in [
    [WorkoutSetStatus.pending, WorkoutSetStatus.pending],
    [WorkoutSetStatus.completed, WorkoutSetStatus.pending],
    [WorkoutSetStatus.completed, WorkoutSetStatus.completed],
  ]) {
    testWidgets('descarta desde atrás con series $statuses', (tester) async {
      final repository = _Repository()
        ..execution = _executionWithStatuses(statuses);
      final (cubit, router) = await _mountSession(tester, repository);
      await tester.tap(find.byTooltip('Salir de la sesión'));
      await tester.pumpAndSettle();
      final discard = find
          .widgetWithText(OutlinedButton, 'Descartar sesión')
          .last;
      await tester.ensureVisible(discard);
      await tester.tap(discard);
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar esta sesión?'), findsOneWidget);
      await tester.tap(find.text('Descartar y salir'));
      await tester.pumpAndSettle();
      expect(repository.discardAttempts, 1);
      expect(repository.abandonAttempts, 0);
      expect(cubit.state.execution, isNull);
      expect(cubit.state.status, ActiveWorkoutStatus.discarded);
      expect(router.state.matchedLocation, '/');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'cancelar y fallar el descarte conserva series y borrador; permite reintentar',
    (tester) async {
      final repository = _Repository()
        ..execution = _executionWithStatuses([
          WorkoutSetStatus.completed,
          WorkoutSetStatus.completed,
        ])
        ..failDiscard = true;
      final (cubit, router) = await _mountSession(tester, repository);
      final notes = find.widgetWithText(TextField, 'Sensaciones');
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Conservar si falla');
      Future<void> open() async {
        await tester.tap(find.byTooltip('Opciones de sesión'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Descartar sesión'));
        await tester.pumpAndSettle();
      }

      await open();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(repository.discardAttempts, 0);
      await open();
      await tester.tap(find.text('Descartar y salir'));
      await tester.pumpAndSettle();
      expect(cubit.state.execution!.completedSetCount, 2);
      expect(router.state.matchedLocation, '/session');
      expect(
        tester.widget<TextField>(notes).controller!.text,
        'Conservar si falla',
      );
      expect(
        find.textContaining('No se ha podido confirmar el descarte'),
        findsOneWidget,
      );
      repository.failDiscard = false;
      await open();
      await tester.tap(find.text('Descartar y salir'));
      await tester.pumpAndSettle();
      expect(repository.discardAttempts, 2);
      expect(router.state.matchedLocation, '/');
      expect(tester.takeException(), isNull);
    },
  );
  test('no ofrece descarte de una ejecución ya cerrada', () async {
    final repository = _Repository()
      ..execution = _execution().copyWith(
        status: WorkoutExecutionStatus.completed,
      );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    expect(await cubit.discard(), false);
    expect(repository.discardAttempts, 0);
  });
  for (final queued in [false, true]) {
    testWidgets(
      'la flecha permite abandonar y volver con sincronización pendiente $queued',
      (tester) async {
        final repository = _Repository()
          ..execution = _executionWithStatuses([
            WorkoutSetStatus.completed,
            WorkoutSetStatus.pending,
          ])
          ..abandonmentDisposition = queued
              ? WorkoutMutationDisposition.queued
              : WorkoutMutationDisposition.synced;
        final savedSets = repository.execution.sets;
        final (cubit, router) = await _mountSession(tester, repository);
        await _chooseExitAbandonment(tester);
        await tester.tap(find.text('Falta de tiempo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Finalizar y conservar'));
        await tester.pumpAndSettle();
        expect(repository.abandonAttempts, 1);
        expect(cubit.state.status, ActiveWorkoutStatus.abandoned);
        expect(cubit.state.execution!.sets, savedSets);
        expect(
          cubit.state.execution!.abandonmentReason,
          WorkoutAbandonmentReason.lackOfTime,
        );
        expect(cubit.state.pendingSyncCount, queued ? 1 : 0);
        expect(router.state.matchedLocation, '/');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'cancelar o fallar el abandono desde atrás mantiene la sesión y el borrador',
    (tester) async {
      final repository = _Repository()
        ..execution = _executionWithStatuses([
          WorkoutSetStatus.completed,
          WorkoutSetStatus.completed,
        ])
        ..failAbandonment = true;
      final (cubit, router) = await _mountSession(tester, repository);
      final savedSets = repository.execution.sets;
      final notes = find.widgetWithText(TextField, 'Sensaciones');
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Borrador que quiero conservar');
      await _chooseExitAbandonment(tester);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(repository.abandonAttempts, 0);
      expect(router.state.matchedLocation, '/session');
      expect(
        tester.widget<TextField>(notes).controller!.text,
        'Borrador que quiero conservar',
      );
      await _chooseExitAbandonment(tester);
      await tester.tap(find.text('Falta de tiempo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finalizar y conservar'));
      await tester.pumpAndSettle();
      expect(cubit.state.status, ActiveWorkoutStatus.failure);
      expect(router.state.matchedLocation, '/session');
      expect(cubit.state.execution!.sets, savedSets);
      expect(
        tester.widget<TextField>(notes).controller!.text,
        'Borrador que quiero conservar',
      );
      repository.failAbandonment = false;
      await _chooseExitAbandonment(tester);
      await tester.tap(find.text('Falta de tiempo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finalizar y conservar'));
      await tester.pumpAndSettle();
      expect(repository.abandonAttempts, 2);
      expect(cubit.state.status, ActiveWorkoutStatus.abandoned);
      expect(router.state.matchedLocation, '/');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('las opciones de salida son accesibles con texto doble', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    final (_, router) = await _mountSession(
      tester,
      repository,
      textScaler: const TextScaler.linear(2),
    );
    await tester.tap(find.byTooltip('Salir de la sesión'));
    await tester.pumpAndSettle();
    final abandon = find.widgetWithText(
      OutlinedButton,
      'Finalizar y conservar lo realizado',
    );
    await tester.ensureVisible(abandon);
    await tester.pumpAndSettle();
    await tester.tap(abandon);
    await tester.pumpAndSettle();
    expect(find.text('Finalizar antes de tiempo'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/session');
    expect(tester.takeException(), isNull);
  });

  for (final (seconds, expectedText) in [
    (20, '00:20'),
    (90, '01:30'),
    (3601, '60:01'),
  ]) {
    testWidgets(
      'el tiempo inicial de $seconds s se puede confirmar sin reescribir',
      (tester) async {
        final repository = _Repository()..execution = _timedExecution(seconds);
        await _mountSession(tester, repository);
        await _openCurrentResult(tester);
        expect(_inlineValue('set-1', 'duration', expectedText), findsOneWidget);
        await _confirmOpenResult(tester);
        expect(repository.lastSetResult?.actualDurationSeconds, seconds);
        expect(find.text('Introduce un tiempo válido'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'el tiempo escrito por el reloj conserva segundos y formato válido',
    (tester) async {
      final repository = _Repository()..execution = _timedExecution(90);
      final (cubit, _) = await _mountSession(tester, repository);
      final timer = tester.widget<WorkoutSetCountdown>(
        find.byType(WorkoutSetCountdown),
      );
      timer.onElapsedChanged(20);
      await tester.pump();
      await tester.tap(find.text('Terminar serie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Series y registros'));
      await tester.pumpAndSettle();
      expect(_inlineValue('set-1', 'duration', '00:20'), findsOneWidget);
      expect(find.byTooltip('Confirmar Serie 1'), findsNothing);
      await tester.tap(find.byTooltip('Cerrar registros'));
      await tester.pumpAndSettle();
      await cubit.finish(finalRpe: 6);
      expect(repository.lastSetResult?.actualDurationSeconds, 20);
      expect(find.text('Introduce un tiempo válido'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('escribir 20 manualmente guarda veinte segundos', (tester) async {
    final repository = _Repository()..execution = _timedExecution(90);
    await _mountSession(tester, repository);
    await _openCurrentResult(tester);
    final field = await _focusInlineField(tester, 'set-1', 'duration');
    await tester.enterText(field, '20');
    expect(tester.widget<TextField>(field).controller!.text, '00:20');
    await _confirmOpenResult(tester);
    expect(repository.lastSetResult?.actualDurationSeconds, 20);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'plancha en tres filas guarda el borrador y confirma con un solo toque',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _Repository()
        ..execution = _execution(templateName: 'Fuerza').copyWith(
          sets: [
            for (var i = 0; i < 3; i++)
              WorkoutExecutionSet(
                id: 'plank-$i',
                blockOrder: 0,
                blockName: 'Core',
                itemOrder: 0,
                exerciseId: 'plank',
                exerciseName: 'Plancha con lastre',
                setOrder: i,
                targetDurationSeconds: 30,
                targetLoadKg: 5,
                targetRpe: 7,
                restAfterSeconds: 60,
                status: i == 0
                    ? WorkoutSetStatus.completed
                    : WorkoutSetStatus.pending,
                actualDurationSeconds: i == 0 ? 32 : null,
                actualLoadKg: i == 0 ? 5 : null,
                actualRpe: i == 0 ? 7 : null,
              ),
          ],
        );
      final (cubit, _) = await _mountSession(tester, repository);
      Future<void> openRecords() async {
        await tester.tap(find.text('Series y registros'));
        await tester.pumpAndSettle();
      }

      await openRecords();
      expect(_inlineCell('plank-0', 'duration').hitTestable(), findsOneWidget);
      expect(_inlineCell('plank-1', 'duration').hitTestable(), findsOneWidget);
      expect(find.text('Por realizar').hitTestable(), findsOneWidget);
      expect(_inlineCell('plank-2', 'duration'), findsNothing);
      expect(_inlineCell('plank-1', 'rir'), findsNothing);
      final time = _inlineCell('plank-1', 'duration');
      final emptyTime = find.byKey(
        const ValueKey('inline-plank-2-duration-value'),
      );
      expect(tester.getSize(time).width, lessThanOrEqualTo(84));
      expect(
        tester.getCenter(time).dx,
        closeTo(tester.getCenter(emptyTime).dx, .1),
      );
      expect(
        tester.getCenter(time).dx,
        closeTo(tester.getCenter(find.text('Tiempo')).dx, .1),
      );
      expect(
        tester.getCenter(time).dy,
        closeTo(tester.getCenter(find.byTooltip('Terminar Serie 2')).dy, .1),
      );
      await capturePerformanceWidget(tester, 'series-en-filas-plancha');
      final timeField = await _focusInlineField(tester, 'plank-1', 'duration');
      expect(tester.widget<TextField>(timeField).controller!.text, isEmpty);
      await tester.enterText(timeField, '34');
      await _enterInlineText(tester, 'plank-1', 'load', '6,5');
      await _enterInlineText(tester, 'plank-1', 'rpe', '8');
      await tester.pumpAndSettle();
      expect(repository.lastSetResult, isNull);
      expect(cubit.state.execution!.currentSet!.id, 'plank-1');
      await tester.tap(find.byTooltip('Cerrar registros'));
      await tester.pumpAndSettle();
      await openRecords();
      expect(_inlineValue('plank-1', 'duration', '00:34'), findsOneWidget);
      await tester.tap(find.byTooltip('Terminar Serie 2'));
      await tester.pumpAndSettle();
      expect(repository.lastSetResult?.actualDurationSeconds, 34);
      expect(repository.lastSetResult?.actualLoadKg, 6.5);
      expect(repository.lastSetResult?.actualRpe, 8);
      expect(cubit.state.status, ActiveWorkoutStatus.resting);
      expect(cubit.state.execution!.currentSet!.id, 'plank-2');
      expect(find.text('Después del descanso'), findsOneWidget);
      expect(find.byTooltip('Cerrar registros'), findsOneWidget);
      final restEndsAt = cubit.state.restEndsAt;
      await _enterInlineText(tester, 'plank-0', 'load', '4');
      await tester.pumpAndSettle();
      expect(cubit.state.drafts['plank-0']?.confirmed, isTrue);
      expect(cubit.state.drafts['plank-0']?.result.actualLoadKg, 4);
      expect(repository.lastSetResult?.resultId, 'plank-1');
      expect(cubit.state.restEndsAt, restEndsAt);
      await tester.tap(find.text('Plancha con lastre').hitTestable().last);
      await tester.pumpAndSettle();
      expect(_inlineCell('plank-0', 'load').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
      cubit.skipRest();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('un reloj de serie en marcha mantiene el control del tiempo', (
    tester,
  ) async {
    final repository = _Repository()..execution = _timedExecution(90);
    final clock = _TimerStore();
    final (cubit, _) = await _mountSession(
      tester,
      repository,
      timerStore: clock,
    );
    clock.snapshot = WorkoutTimerSnapshot(
      phase: WorkoutTimerPhase.running,
      targetSeconds: 90,
      preparationSeconds: 3,
      phaseStartedAt: DateTime.now().toUtc(),
      elapsedBeforeRun: Duration.zero,
    );
    await tester.tap(find.text('Series y registros'));
    await tester.pumpAndSettle();
    expect(find.text('Cronómetro en el entreno'), findsOneWidget);
    expect(_inlineCell('set-1', 'duration'), findsNothing);
    expect(find.byTooltip('Terminar Serie 1'), findsNothing);
    expect(cubit.state.execution!.currentSet!.id, 'set-1');
    expect(repository.lastSetResult, isNull);
  });

  testWidgets(
    'móvil muestra los datos sin editores abiertos y conserva el borrador al plegar',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _Repository()..execution = _timedExecution(30);
      final (cubit, _) = await _mountSession(tester, repository);
      await tester.tap(find.text('Terminar serie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revisar series'));
      await tester.pumpAndSettle();

      final time = _inlineField('set-1', 'duration');
      final load = _inlineField('set-1', 'load');
      final timeCell = _inlineCell('set-1', 'duration');
      final loadCell = _inlineCell('set-1', 'load');
      final midpoint =
          (tester.getCenter(timeCell).dx + tester.getCenter(loadCell).dx) / 2;
      expect(midpoint, closeTo(195, .1));
      expect(
        find.descendant(of: timeCell, matching: find.text('00:30')),
        findsOneWidget,
      );
      expect(time, findsNothing);
      expect(load, findsNothing);
      await tester.tap(timeCell);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(time, '34');
      await tester.tap(loadCell);
      await tester.pumpAndSettle();
      expect(time, findsNothing);
      expect(
        find.descendant(of: timeCell, matching: find.text('00:34')),
        findsOneWidget,
      );
      await tester.enterText(load, '2,5');
      final exercise = find.text('Plancha').hitTestable().last;
      await tester.tap(exercise);
      await tester.pumpAndSettle();
      expect(load, findsNothing);
      await tester.tap(exercise);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: loadCell, matching: find.text('2,5')),
        findsOneWidget,
      );
      expect(cubit.state.drafts['set-1']?.confirmed, isTrue);
      expect(find.byTooltip('Confirmar Serie 1'), findsNothing);
      expect(find.text('Registrada'), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar registros'));
      await tester.pumpAndSettle();
      await cubit.finish(finalRpe: 6);
      await tester.pumpAndSettle();
      expect(repository.lastSetResult?.actualDurationSeconds, 34);
      expect(repository.lastSetResult?.actualLoadKg, 2.5);
      expect(repository.execution.status, WorkoutExecutionStatus.completed);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('las repeticiones escritas cuentan al terminar la serie', (
    tester,
  ) async {
    final repository = _Repository()
      ..execution = _execution(format: WorkoutBlockFormat.straightSets);
    final (cubit, _) = await _mountSession(tester, repository);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Repeticiones realizadas'),
      '6',
    );
    await tester.tap(find.text('Terminar serie'));
    await tester.pumpAndSettle();
    expect(cubit.state.unconfirmedDraftCount, 0);
    cubit.skipRest();
    await cubit.skipCurrentSet();
    await cubit.finish(finalRpe: 6);
    expect(repository.lastSetResult?.actualReps, 6);
    expect(repository.execution.status, WorkoutExecutionStatus.completed);
  });

  testWidgets('el tiempo medido cuenta aunque coincida con el objetivo', (
    tester,
  ) async {
    final repository = _Repository()..execution = _timedExecution(30);
    final (cubit, _) = await _mountSession(tester, repository);
    final clock = tester.widget<WorkoutSetCountdown>(
      find.byType(WorkoutSetCountdown),
    );
    clock.onElapsedChanged(30);
    await tester.tap(find.text('Terminar serie'));
    await tester.pumpAndSettle();
    expect(cubit.state.unconfirmedDraftCount, 0);
    await cubit.finish(finalRpe: 6);
    expect(repository.lastSetResult?.actualDurationSeconds, 30);
    expect(repository.execution.status, WorkoutExecutionStatus.completed);
  });

  test(
    'un cierre parcial conserva los metros medidos y la otra serie pendiente',
    () async {
      final repository = _Repository()
        ..execution = _execution(allowUnrecorded: true).copyWith(
          sets: [
            const WorkoutExecutionSet(
              id: 'carry',
              blockOrder: 0,
              blockName: 'Fuerza',
              itemOrder: 0,
              exerciseId: 'carry',
              exerciseName: 'Paseo del granjero',
              setOrder: 0,
              targetDistanceMeters: 100,
              restAfterSeconds: 0,
              status: WorkoutSetStatus.pending,
            ),
            _execution().sets.last,
          ],
        );
      final store = MemoryWorkoutSessionDraftStore();
      final cubit = _cubit(repository, sessionDraftStore: store);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.updateDraft(
        const WorkoutSetResultInput(
          resultId: 'carry',
          actualDistanceMeters: 95,
        ),
        {'distance': '95', 'load': 'kg'},
        hasMeasuredResult: true,
      );
      await cubit.endCurrentSet();
      expect(cubit.state.unconfirmedDraftCount, 1);
      await cubit.updateDraft(
        const WorkoutSetResultInput(
          resultId: 'carry',
          actualDistanceMeters: 95,
          actualLoadKg: 14,
        ),
        {'distance': '95', 'load': '14'},
        hasMeasuredResult: true,
      );
      expect(cubit.state.unconfirmedDraftCount, 0);
      await cubit.finishWithoutFullRecording();
      expect(repository.lastSetResult?.actualDistanceMeters, 95);
      expect(repository.lastSetResult?.actualLoadKg, 14);
      expect(repository.execution.sets.last.status, WorkoutSetStatus.pending);
      expect(repository.execution.status, WorkoutExecutionStatus.completed);
    },
  );

  for (final scenario in <String, List<WorkoutSetStatus>>{
    'antes de confirmar ninguna serie': [
      WorkoutSetStatus.pending,
      WorkoutSetStatus.pending,
    ],
    'con parte del trabajo confirmado': [
      WorkoutSetStatus.completed,
      WorkoutSetStatus.pending,
    ],
    'después de confirmar todas las series': [
      WorkoutSetStatus.completed,
      WorkoutSetStatus.completed,
    ],
    'después de omitir todas las series': [
      WorkoutSetStatus.skipped,
      WorkoutSetStatus.skipped,
    ],
  }.entries) {
    testWidgets('permite abandonar ${scenario.key} sin inventar resultados', (
      tester,
    ) async {
      final repository = _Repository()
        ..execution = _executionWithStatuses(scenario.value);
      final savedSets = repository.execution.sets;
      final (cubit, router) = await _mountSession(tester, repository);

      await _openAbandonment(tester);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Finalizar y conservar'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(repository.abandonAttempts, 0);
      expect(cubit.state.execution!.status, WorkoutExecutionStatus.inProgress);

      await _confirmAbandonment(tester);
      expect(repository.abandonAttempts, 1);
      expect(repository.execution.status, WorkoutExecutionStatus.abandoned);
      expect(
        repository.execution.abandonmentReason,
        WorkoutAbandonmentReason.lackOfTime,
      );
      expect(cubit.state.execution!.sets, savedSets);
      expect(cubit.state.execution!.finalRpe, isNull);
      expect(
        find.text('Lo realizado se conserva para tu historial.'),
        findsOneWidget,
      );
      expect(find.text('Finalizar y conservar lo realizado'), findsNothing);

      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/');
      expect(find.text('¿Salir de la sesión?'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'fallar el abandono conserva el borrador final y permite reintentar',
    (tester) async {
      final repository = _Repository()
        ..execution = _executionWithStatuses([
          WorkoutSetStatus.completed,
          WorkoutSetStatus.completed,
        ])
        ..failAbandonment = true;
      final savedSets = repository.execution.sets;
      final (cubit, _) = await _mountSession(tester, repository);
      const draft = 'He hecho las series, pero tengo que salir.';
      final notes = find.widgetWithText(TextField, 'Sensaciones');
      await tester.ensureVisible(notes);
      await tester.enterText(notes, draft);
      await _confirmAbandonment(tester);

      expect(cubit.state.status, ActiveWorkoutStatus.failure);
      expect(find.text('No hemos podido abandonar la sesión.'), findsOneWidget);
      expect(tester.widget<TextField>(notes).controller!.text, draft);
      expect(cubit.state.execution!.sets, savedSets);
      expect(repository.execution.status, WorkoutExecutionStatus.inProgress);

      repository.failAbandonment = false;
      await _confirmAbandonment(tester);
      expect(repository.abandonAttempts, 2);
      expect(cubit.state.status, ActiveWorkoutStatus.abandoned);
      expect(cubit.state.execution!.sets, savedSets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'el abandono pendiente de sincronizar cierra sin perder las series',
    (tester) async {
      final repository = _Repository()
        ..execution = _executionWithStatuses([
          WorkoutSetStatus.completed,
          WorkoutSetStatus.completed,
        ])
        ..abandonmentDisposition = WorkoutMutationDisposition.queued;
      final savedSets = repository.execution.sets;
      final (cubit, _) = await _mountSession(tester, repository);
      await _confirmAbandonment(tester);

      expect(cubit.state.status, ActiveWorkoutStatus.abandoned);
      expect(cubit.state.execution!.status, WorkoutExecutionStatus.abandoned);
      expect(cubit.state.execution!.sets, savedSets);
      expect(
        cubit.state.execution!.abandonmentReason,
        WorkoutAbandonmentReason.lackOfTime,
      );
      expect(cubit.state.pendingSyncCount, 1);
      expect(find.text('Resultado pendiente de sincronizar'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(
                TextButton,
                'Resultado pendiente de sincronizar',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(repository.execution.status, WorkoutExecutionStatus.inProgress);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el descanso avisa a mitad, diez segundos y final', (
    tester,
  ) async {
    final repository = _Repository();
    final cues = _CueService();
    final cubit = _cubit(repository, cueService: cues);
    await cubit.load();
    await cubit.completeCurrentSet(
      const WorkoutSetResultInput(resultId: 'set-1', actualReps: 8),
      restSecondsOverride: 40,
    );
    await tester.pump(const Duration(seconds: 20));
    expect(cues.cues, [WorkoutCue.halfway]);
    await tester.pump(const Duration(seconds: 10));
    expect(cues.cues, [WorkoutCue.halfway, WorkoutCue.tenSecondsRemaining]);
    await tester.pump(const Duration(seconds: 10));
    expect(cues.cues.last, WorkoutCue.restFinished);
    expect(cubit.state.status, ActiveWorkoutStatus.ready);
    await cubit.close();
  });

  testWidgets(
    'restaurar un descanso conserva la mitad original y no repite hitos',
    (tester) async {
      final repository = _Repository();
      final cues = _CueService();
      final store = _TimerStore(
        WorkoutTimerSnapshot(
          phase: WorkoutTimerPhase.running,
          targetSeconds: 40,
          preparationSeconds: 0,
          phaseStartedAt: DateTime.now().toUtc(),
          elapsedBeforeRun: const Duration(seconds: 25),
        ),
      );
      final cubit = _cubit(repository, timerStore: store, cueService: cues);
      await cubit.load();
      expect(store.snapshot!.targetSeconds, 40);
      expect(store.snapshot!.elapsedBeforeRun.inSeconds, 25);
      await tester.pump(const Duration(seconds: 5));
      expect(cues.cues, [WorkoutCue.tenSecondsRemaining]);
      cubit.skipRest();
      await tester.pump(const Duration(seconds: 10));
      expect(cues.cues, [WorkoutCue.tenSecondsRemaining]);
      await cubit.close();
    },
  );

  testWidgets('solo ofrece el permiso después de cargar una sesión activa', (
    tester,
  ) async {
    final cubit = _cubit(_Repository());
    addTearDown(cubit.close);
    final cues = _CueService()..offerPermission = true;
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: ActiveWorkoutPage(timerStore: _TimerStore(), cueService: cues),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Avisos de la sesión'), findsNothing);
    expect(cues.permissionChecks, 0);
    await cubit.load();
    await tester.pumpAndSettle();
    expect(find.text('Avisos de la sesión'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(cues.offerPermission, isFalse);
    expect(find.text('Entrenamiento en curso'), findsOneWidget);
    expect(cubit.state.execution, isNotNull);
  });

  for (final scenario in [
    (bySwipe: false, platform: TargetPlatform.iOS),
    (bySwipe: true, platform: TargetPlatform.iOS),
    (bySwipe: true, platform: TargetPlatform.android),
  ]) {
    final bySwipe = scenario.bySwipe;
    testWidgets('salir y retomar conserva series, $scenario', (tester) async {
      final repository = _Repository();
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.completeCurrentSet(
        const WorkoutSetResultInput(resultId: 'set-1', actualReps: 8),
        restSecondsOverride: 0,
      );
      final savedExecution = cubit.state.execution!;
      if (bySwipe) {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      final registry = WorkflowExitRegistry();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: FilledButton(
                onPressed: () => context.push('/session'),
                child: const Text('Retomar'),
              ),
            ),
          ),
          materialAppRoute(
            path: '/session',
            onExit: (context, state) => registry.requestExit(state.pageKey),
            builder: (context, state) => WorkflowExitScope(
              controller: registry.controller(state.pageKey),
              child: BlocProvider.value(
                value: cubit,
                child: ActiveWorkoutPage(
                  timerStore: _TimerStore(),
                  cueService: _CueService(),
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: withAppBackGesture(
            EntrenaTheme.dark.copyWith(platform: scenario.platform),
          ),
          routerConfig: router,
        ),
      );
      router.push('/session');
      await tester.pumpAndSettle();
      if (bySwipe) {
        await tester.dragFrom(const Offset(2, 400), const Offset(310, 0));
      } else {
        await tester.tap(find.byTooltip('Salir de la sesión'));
      }
      await tester.pumpAndSettle();
      expect(find.text('¿Salir de la sesión?'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, '/session');
      if (bySwipe) {
        await tester.dragFrom(const Offset(2, 400), const Offset(310, 0));
      } else {
        await tester.tap(find.byTooltip('Salir de la sesión'));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir y retomar después'));
      await tester.pumpAndSettle();
      expect(cubit.state.execution, savedExecution);
      expect(repository.execution.status, WorkoutExecutionStatus.inProgress);
      await tester.tap(find.text('Retomar'));
      await tester.pumpAndSettle();
      expect(cubit.state.execution!.completedSetCount, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'omitir calentamiento pasa al trabajo sin resultados inventados',
    (tester) async {
      final repository = _Repository();
      repository.execution = repository.execution.copyWith(
        sets: const [
          WorkoutExecutionSet(
            id: 'warm-1',
            blockOrder: 0,
            blockName: 'Calentamiento',
            blockFormat: WorkoutBlockFormat.warmUp,
            itemOrder: 0,
            exerciseId: 'mobility',
            exerciseName: 'Movilidad',
            itemInstructions: 'Activación suave\nCamina con comodidad.',
            setOrder: 0,
            targetDurationSeconds: 180,
            restAfterSeconds: 0,
            status: WorkoutSetStatus.pending,
          ),
          WorkoutExecutionSet(
            id: 'warm-2',
            blockOrder: 0,
            blockName: 'Calentamiento',
            blockFormat: WorkoutBlockFormat.warmUp,
            itemOrder: 1,
            exerciseId: 'mobility',
            exerciseName: 'Movilidad',
            setOrder: 0,
            targetDurationSeconds: 120,
            restAfterSeconds: 0,
            status: WorkoutSetStatus.pending,
          ),
          WorkoutExecutionSet(
            id: 'work',
            blockOrder: 1,
            blockName: 'Trabajo',
            itemOrder: 0,
            exerciseId: 'push',
            exerciseName: 'Flexiones',
            setOrder: 0,
            targetReps: 8,
            restAfterSeconds: 0,
            status: WorkoutSetStatus.pending,
          ),
        ],
      );
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: ActiveWorkoutPage(
              timerStore: _TimerStore(),
              cueService: _CueService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Omitir calentamiento'));
      await tester.tap(find.text('Omitir calentamiento'));
      await tester.pumpAndSettle();
      expect(cubit.state.execution!.currentSet!.id, 'work');
      expect(
        cubit.state.execution!.sets
            .take(2)
            .every((s) => s.status == WorkoutSetStatus.skipped),
        isTrue,
      );
      expect(repository.lastSetResult, isNull);
      expect(find.text('Terminar serie'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  Future<(_Repository, ActiveWorkoutCubit)> mountEffortSet(
    WidgetTester tester, {
    bool duration = false,
    double? previousRir,
  }) async {
    final repository = _Repository();
    repository.execution = repository.execution.copyWith(
      sets: [
        WorkoutExecutionSet(
          id: 'effort-set',
          blockOrder: 0,
          blockName: 'Trabajo',
          itemOrder: 0,
          exerciseId: 'push-up',
          exerciseName: 'Flexiones',
          setOrder: 0,
          targetReps: duration ? null : 8,
          targetDurationSeconds: duration ? 30 : null,
          targetRir: 3,
          targetRpe: 7,
          restAfterSeconds: 0,
          status: WorkoutSetStatus.pending,
        ),
      ],
    );
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    if (previousRir != null) {
      await cubit.updateDraft(
        WorkoutSetResultInput(
          resultId: 'effort-set',
          actualRir: previousRir,
          actualReps: duration ? null : 8,
          actualDurationSeconds: duration ? 30 : null,
        ),
        {'reps': duration ? '' : '8', 'duration': duration ? '00:30' : ''},
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: ActiveWorkoutPage(
            timerStore: _TimerStore(),
            cueService: _CueService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (repository, cubit);
  }

  testWidgets('guardar sin declarar esfuerzo conserva RIR y RPE ausentes', (
    tester,
  ) async {
    final (repository, _) = await mountEffortSet(tester);
    await _finishAndConfirmCurrent(tester);
    expect(repository.lastSetResult?.actualReps, 8);
    expect(repository.lastSetResult?.actualRir, isNull);
    expect(repository.lastSetResult?.actualRpe, isNull);
  });
  testWidgets(
    'RIR cero declarado llega al repositorio y no se sustituye por el objetivo',
    (tester) async {
      final (repository, _) = await mountEffortSet(tester);
      final field = find.widgetWithText(WorkoutEffortField, 'RIR real');
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, '2.5'), findsNothing);
      await tester.tap(find.text('0').last);
      await tester.pumpAndSettle();
      await _finishAndConfirmCurrent(tester);
      expect(repository.lastSetResult?.actualRir, 0);
      expect(repository.lastSetResult?.actualRpe, isNull);
    },
  );
  testWidgets('una duración heredada no pide ni envía RIR nuevo', (
    tester,
  ) async {
    final (repository, cubit) = await mountEffortSet(
      tester,
      duration: true,
      previousRir: 2.5,
    );
    expect(find.widgetWithText(WorkoutEffortField, 'RIR real'), findsNothing);
    expect(find.text('RIR 3'), findsNothing);
    await _openCurrentResult(tester);
    expect(find.widgetWithText(WorkoutEffortField, 'RIR real'), findsNothing);
    await _enterInlineText(tester, 'effort-set', 'duration', '0035');
    await tester.pumpAndSettle();
    expect(cubit.state.drafts['effort-set']?.result.actualRir, 2.5);
    await _confirmOpenResult(tester);
    expect(repository.lastSetResult?.actualDurationSeconds, 35);
    expect(repository.lastSetResult?.actualRir, isNull);
  });
  test('un EMOM descansa solo hasta el siguiente minuto', () async {
    final repository = _Repository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.completeCurrentSet(
      const WorkoutSetResultInput(resultId: 'set-1', actualReps: 8),
      restSecondsOverride: 42,
    );

    expect(cubit.state.status, ActiveWorkoutStatus.resting);
    expect(cubit.state.restSecondsRemaining, 42);
    expect(cubit.state.restCanBeSkipped, isFalse);
    expect(cubit.state.execution?.currentSet?.id, 'set-2');
  });

  test('omitir una estación EMOM conserva el minuto en curso', () async {
    final repository = _Repository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.skipCurrentSet(restSecondsOverride: 31);

    expect(cubit.state.status, ActiveWorkoutStatus.resting);
    expect(cubit.state.restSecondsRemaining, 31);
    expect(cubit.state.restCanBeSkipped, isFalse);
    expect(cubit.state.execution?.currentSet?.id, 'set-2');
  });

  test('restaura la espera hasta el siguiente minuto al volver', () async {
    final repository = _Repository();
    final timerStore = _TimerStore(
      WorkoutTimerSnapshot(
        phase: WorkoutTimerPhase.running,
        targetSeconds: 42,
        preparationSeconds: 0,
        phaseStartedAt: DateTime.now().toUtc().subtract(
          const Duration(seconds: 5),
        ),
        elapsedBeforeRun: Duration.zero,
        restCanBeSkipped: false,
      ),
    );
    final cubit = _cubit(repository, timerStore: timerStore);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, ActiveWorkoutStatus.resting);
    expect(cubit.state.restSecondsRemaining, inInclusiveRange(36, 37));
    expect(cubit.state.restCanBeSkipped, isFalse);
  });

  test('guarda las vueltas y el parcial de un AMRAP', () async {
    final repository = _Repository()..execution = _amrapExecution();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.completeCurrentAmrap(
      const WorkoutAmrapResultInput(
        executionId: 'execution-1',
        blockOrder: 0,
        completedRounds: 4,
        partialItemOrder: 1,
        partialReps: 3,
      ),
    );

    expect(cubit.state.status, ActiveWorkoutStatus.ready);
    expect(cubit.state.execution?.currentSet, isNull);
    final result = cubit.state.execution?.amrapResults.single;
    expect(result?.completedRounds, 4);
    expect(result?.partialItemOrder, 1);
    expect(result?.partialReps, 3);
  });
  test('AMRAP recupera vueltas sin escribir resultados deportivos', () async {
    final repository = _Repository()..execution = _amrapExecution();
    final store = MemoryWorkoutAmrapDraftStore();
    final first = _cubit(repository, amrapDraftStore: store);
    await first.load();
    await first.updateAmrapDraft(
      0,
      const WorkoutAmrapDraft(
        rounds: '5',
        hasPartial: true,
        partialItemOrder: 1,
        partialReps: '',
      ),
    );
    expect(repository.amrapAttempts, 0);
    await first.abandon(WorkoutAbandonmentReason.lackOfTime);
    expect(repository.abandonAttempts, 0);
    expect(first.state.errorMessage, contains('Revisa el resultado AMRAP'));
    await Future.wait([
      first.changeAmrapRounds(0, 1),
      first.changeAmrapRounds(0, 1),
    ]);
    expect(first.state.amrapDrafts[0]?.rounds, '7');
    await first.close();
    final resumed = _cubit(repository, amrapDraftStore: store);
    addTearDown(resumed.close);
    await resumed.load();
    expect(resumed.state.amrapDrafts[0]?.rounds, '7');
    expect(resumed.state.amrapDrafts[0]?.partialReps, '');
    expect(resumed.state.execution?.currentSet, isNotNull);
    store.failWrite = true;
    await resumed.updateAmrapDraft(0, const WorkoutAmrapDraft(rounds: '6'));
    expect(resumed.state.amrapDrafts[0]?.rounds, '6');
    expect(resumed.state.errorMessage, contains('este dispositivo'));
  });

  test('AMRAP guardado no depende de releer ni de limpiar el reloj', () async {
    final repository = _Repository()
      ..execution = _amrapExecution()
      ..failReadAfterAmrap = true
      ..failPendingAfterAmrap = true;
    final timer = _TimerStore()..failClear = true;
    final cubit = _cubit(repository, timerStore: timer);
    addTearDown(cubit.close);
    await cubit.load();
    const input = WorkoutAmrapResultInput(
      executionId: 'execution-1',
      blockOrder: 0,
      completedRounds: 5,
      partialItemOrder: 1,
      partialReps: 4,
    );
    expect(await cubit.completeCurrentAmrap(input), true);
    expect(cubit.state.execution?.currentSet, isNull);
    expect(cubit.state.execution?.amrapResults.single.completedRounds, 5);
    expect(cubit.state.status, ActiveWorkoutStatus.ready);
    expect(await cubit.completeCurrentAmrap(input), false);
    expect(repository.amrapAttempts, 1);
  });

  test(
    'AMRAP rechaza otra ejecución y parciales inválidos antes de enviar',
    () async {
      final repository = _Repository()..execution = _amrapExecution();
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      for (final input in [
        const WorkoutAmrapResultInput(
          executionId: 'otra',
          blockOrder: 0,
          completedRounds: 5,
        ),
        const WorkoutAmrapResultInput(
          executionId: 'execution-1',
          blockOrder: 0,
          completedRounds: -1,
        ),
        const WorkoutAmrapResultInput(
          executionId: 'execution-1',
          blockOrder: 0,
          completedRounds: 5,
          partialItemOrder: 1,
          partialReps: 8,
        ),
      ]) {
        expect(await cubit.completeCurrentAmrap(input), false);
      }
      expect(repository.amrapAttempts, 0);
    },
  );

  for (final (width, height, scale) in [
    (390.0, 844.0, 1.2),
    (412.0, 915.0, 1.2),
    (320.0, 568.0, 2.0),
  ]) {
    testWidgets('AMRAP circuito, ficha y revisión a $width px texto $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.reset);
      final imagePath = Platform.environment['REVIEW_EXERCISE_IMAGE'];
      final bytes = imagePath == null
          ? base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGP8HyXCgA0wYRUdtBIAIlABfcyTUMcAAAAASUVORK5CYII=',
            )
          : (await tester.runAsync(() => File(imagePath).readAsBytes()))!;
      debugNetworkImageHttpClientProvider = () => reviewImageHttpClient(bytes);
      addTearDown(() {
        debugNetworkImageHttpClientProvider = null;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
      final repository = _Repository()
        ..execution = amrapFixture(executionId: 'execution-1');
      final (cubit, _) = await _mountSession(
        tester,
        repository,
        textScaler: TextScaler.linear(scale),
        getExercise: GetExerciseByIdUseCase(_AmrapExercises()),
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutAmrapExerciseTile), findsNWidgets(3));
      expect(find.byType(Image), findsNWidgets(3));
      if (width >= 390) {
        expect(
          find.text('Sentadilla con peso corporal').hitTestable(),
          findsOneWidget,
        );
        final lastCard = tester.getRect(
          find.byType(WorkoutAmrapExerciseTile).last,
        );
        final counter = tester.getRect(find.text('1 vuelta'));
        expect(lastCard.bottom, lessThan(counter.top));
      }

      expect(find.text('0 de 3 series completadas'), findsNothing);
      await tester.ensureVisible(find.text('1 vuelta'));
      await tester.tap(find.text('1 vuelta'));
      await tester.pumpAndSettle();
      expect(cubit.state.amrapDrafts[0]?.rounds, '1');
      expect(repository.amrapAttempts, 0);
      await tester.ensureVisible(
        (scale > 1.3
            ? find.text('Iniciar temporizador')
            : find.byTooltip('Iniciar temporizador')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        (scale > 1.3
            ? find.text('Iniciar temporizador')
            : find.byTooltip('Iniciar temporizador')),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.byTooltip('Reiniciar temporizador'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reiniciar temporizador'));
      await tester.pumpAndSettle();
      expect(cubit.state.amrapDrafts[0]?.rounds, '1');
      await tester.ensureVisible(find.byTooltip('Restar una vuelta'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Restar una vuelta'));
      await tester.pumpAndSettle();
      expect(cubit.state.amrapDrafts[0]?.rounds, '0');
      await tester.ensureVisible(find.text('Flexiones'));
      await tester.tap(find.text('Flexiones'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseDetailSheet), findsOneWidget);
      expect(find.text('Editar ejercicio'), findsNothing);
      await tester.tap(find.byTooltip('Cerrar detalle'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Series y registros'));
      await tester.tap(find.byTooltip('Series y registros'));
      await tester.pumpAndSettle();
      expect(find.text('Principal · AMRAP'), findsOneWidget);
      expect(find.text('Serie · ronda 1'), findsNothing);
      await tester.tap(find.byTooltip('Cerrar registros'));
      await tester.pumpAndSettle();
      await capturePerformanceWidget(tester, 'amrap-circuito-${width.toInt()}');
      await tester.ensureVisible(find.text('Terminar AMRAP'));
      await tester.tap(find.text('Terminar AMRAP'));
      await tester.pumpAndSettle();
      final rounds = find.byKey(const ValueKey('amrap-rounds-0'));
      await tester.ensureVisible(rounds);
      await tester.enterText(rounds, '5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, false);
      await tester.ensureVisible(find.text('¿Empezaste otra vuelta?'));
      await tester.tap(find.text('¿Empezaste otra vuelta?'));
      await tester.pumpAndSettle();
      final selected = find.descendant(
        of: find.byType(WorkoutAmrapReview),
        matching: find.text('Sentadilla con peso corporal'),
      );
      await tester.ensureVisible(selected);
      await tester.tap(selected);
      await tester.pumpAndSettle();
      final reps = find.byKey(const ValueKey('amrap-reps-2'));
      await tester.ensureVisible(reps);
      await tester.enterText(reps, '4');
      // Volver a tocar la selección actual no debe borrar lo ya introducido.
      await tester.ensureVisible(selected);
      await tester.pumpAndSettle();
      await tester.tap(selected);
      await tester.pumpAndSettle();
      expect(cubit.state.amrapDrafts[0]?.partialReps, '4');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar resultado'));
      expect(find.text('Guardar resultado').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      await tester.ensureVisible(reps);
      await capturePerformanceWidget(tester, 'amrap-parcial-${width.toInt()}');
      repository.failAmrap = true;
      await tester.ensureVisible(find.text('Guardar resultado'));
      await tester.tap(find.text('Guardar resultado'));
      await tester.pumpAndSettle();
      expect(cubit.state.amrapDrafts[0]?.rounds, '5');
      expect(cubit.state.amrapDrafts[0]?.partialReps, '4');
      expect(
        find.textContaining('Tus datos se conservan').last,
        findsOneWidget,
      );
      repository.failAmrap = false;
      await tester.ensureVisible(find.text('Guardar resultado'));
      await tester.tap(find.text('Guardar resultado'));
      await tester.pumpAndSettle();
      final saved = cubit.state.execution!.amrapResults.single;
      expect(saved.completedRounds, 5);
      expect(saved.partialItemOrder, 2);
      expect(saved.partialReps, 4);
      expect(cubit.state.amrapDrafts, isEmpty);
      expect(find.byType(WorkoutAmrapReview), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugNetworkImageHttpClientProvider = null;
    });
  }
}

WorkoutExecution _executionWithStatuses(
  List<WorkoutSetStatus> statuses, {
  bool allowUnrecorded = false,
}) {
  final execution = _execution(allowUnrecorded: allowUnrecorded);
  return execution.copyWith(
    sets: [
      for (var i = 0; i < execution.sets.length; i++)
        execution.sets[i].copyWith(
          status: statuses[i],
          actualReps: statuses[i] == WorkoutSetStatus.completed ? 8 : null,
          completedAt: statuses[i] == WorkoutSetStatus.pending
              ? null
              : DateTime.utc(2026, 10, 8, 17, i),
        ),
    ],
  );
}

WorkoutExecution _timedExecution(int seconds) => _execution().copyWith(
  sets: [
    WorkoutExecutionSet(
      id: 'set-1',
      blockOrder: 0,
      blockName: 'Trabajo',
      itemOrder: 0,
      exerciseId: 'plank',
      exerciseName: 'Plancha',
      setOrder: 0,
      targetDurationSeconds: seconds,
      targetRir: 2,
      restAfterSeconds: 0,
      status: WorkoutSetStatus.pending,
    ),
  ],
);

Future<(ActiveWorkoutCubit, GoRouter)> _mountSession(
  WidgetTester tester,
  _Repository repository, {
  TextScaler textScaler = TextScaler.noScaling,
  GetExerciseByIdUseCase? getExercise,
  PhoneRunCubit Function(String)? createPhoneRun,
  WorkoutLockScreen? lockScreen,
  DateTime Function()? now,
  WorkoutSessionDraftStore? sessionDraftStore,
  _TimerStore? timerStore,
}) async {
  final cubit = _cubit(
    repository,
    getExercise: getExercise,
    now: now,
    sessionDraftStore: sessionDraftStore,
    timerStore: timerStore,
  );
  addTearDown(cubit.close);
  await cubit.load();
  final registry = WorkflowExitRegistry();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Mi semana')),
      ),
      GoRoute(
        path: '/session',
        onExit: (context, state) => registry.requestExit(state.pageKey),
        builder: (context, state) => WorkflowExitScope(
          controller: registry.controller(state.pageKey),
          child: BlocProvider.value(
            value: cubit,
            child: ActiveWorkoutPage(
              timerStore: timerStore ?? _TimerStore(),
              cueService: _CueService(),
              lockScreen: lockScreen,
              createPhoneRun: createPhoneRun,
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: EntrenaTheme.dark,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: child!,
        ),
      ),
    ),
  );
  router.push('/session');
  await tester.pumpAndSettle();
  return (cubit, router);
}

const _phoneRunSet = WorkoutExecutionSet(
  id: 'run',
  blockOrder: 0,
  blockName: 'Rodaje continuo',
  blockFormat: WorkoutBlockFormat.running,
  itemOrder: 0,
  exerciseId: runningExerciseId,
  exerciseName: 'Carrera',
  setOrder: 0,
  targetDurationSeconds: 180,
  restAfterSeconds: 0,
  status: WorkoutSetStatus.pending,
);

class _RunLocation implements PhoneRunLocationSource {
  final starts = <String>[];
  final stops = <String>[];
  final events = StreamController<PhoneRunLocationEvent>.broadcast(sync: true);

  @override
  Stream<PhoneRunLocationEvent> get locations => events.stream;

  @override
  Future<void> start(String token) async => starts.add(token);

  @override
  Future<void> stop(String token) async => stops.add(token);

  void fix(DateTime at, double longitude) => events.add(
    PhoneRunLocationEvent(
      starts.last,
      fix: PhoneRunFix(
        latitude: 0,
        longitude: longitude,
        accuracyMeters: 5,
        at: at,
      ),
    ),
  );
}

class _EmptyRunCheckpoints extends Fake implements PhoneRunCheckpoints {
  @override
  Future<PhoneRunCheckpoint?> read(String executionId) async => null;
}

class _MemoryRunCheckpoints implements PhoneRunCheckpoints {
  PhoneRunCheckpoint? _checkpoint;

  @override
  Future<PhoneRunCheckpoint?> read(String executionId) async => _checkpoint;

  @override
  Future<void> write(String executionId, PhoneRunCheckpoint value) async =>
      _checkpoint = value;

  @override
  Future<void> clear(String executionId) async => _checkpoint = null;
}

Future<void> _finishAndConfirmCurrent(WidgetTester tester) async {
  await _openCurrentResult(tester);
  await _confirmOpenResult(tester);
}

Future<void> _openCurrentResult(WidgetTester tester) async {
  await tester.tap(find.text('Terminar serie'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Series y registros').last);
  await tester.pumpAndSettle();
  if (find.byTooltip('Confirmar Serie 1').evaluate().isEmpty) {
    await tester.tap(find.textContaining('Datos por confirmar').first);
    await tester.pumpAndSettle();
  }
}

Future<void> _confirmOpenResult(WidgetTester tester) async {
  final inline = find.byTooltip('Confirmar Serie 1');
  final confirm = inline.evaluate().isNotEmpty
      ? inline
      : find.text('Confirmar datos');
  await tester.ensureVisible(confirm);
  await tester.tap(confirm);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Cerrar registros'));
  await tester.pumpAndSettle();
}

Finder _inlineField(String id, String field) =>
    find.byKey(ValueKey('inline-$id-$field'));

Finder _inlineCell(String id, String field) =>
    find.byKey(ValueKey('inline-cell-$id-$field'));

Finder _inlineValue(String id, String field, String value) =>
    find.descendant(of: _inlineCell(id, field), matching: find.text(value));

Future<Finder> _focusInlineField(
  WidgetTester tester,
  String id,
  String field,
) async {
  final cell = _inlineCell(id, field);
  await tester.ensureVisible(cell);
  await tester.tap(cell);
  await tester.pumpAndSettle();
  return _inlineField(id, field);
}

Future<void> _enterInlineText(
  WidgetTester tester,
  String id,
  String field,
  String text,
) async {
  final editor = await _focusInlineField(tester, id, field);
  await tester.enterText(editor, text);
}

Future<void> _chooseExitAbandonment(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Salir de la sesión'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(OutlinedButton, 'Finalizar y conservar lo realizado'),
  );
  await tester.pumpAndSettle();
}

Future<void> _chooseExitPartialCompletion(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Salir de la sesión'));
  await tester.pumpAndSettle();
  final finish = find.widgetWithText(
    OutlinedButton,
    'Terminar sin registrar todo',
  );
  await tester.ensureVisible(finish);
  await tester.tap(finish);
  await tester.pumpAndSettle();
}

Future<void> _openAbandonment(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Opciones de sesión'));
  await tester.pumpAndSettle();
  final abandon = find.text('Finalizar y conservar lo realizado');
  expect(abandon, findsOneWidget);
  await tester.ensureVisible(abandon);
  await tester.pumpAndSettle();
  await tester.tap(abandon);
  await tester.pumpAndSettle();
}

Future<void> _confirmAbandonment(WidgetTester tester) async {
  await _openAbandonment(tester);
  await tester.tap(find.text('Falta de tiempo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Finalizar y conservar'));
  await tester.pumpAndSettle();
}

ActiveWorkoutCubit _cubit(
  _Repository repository, {
  _TimerStore? timerStore,
  _CueService? cueService,
  WorkoutSessionDraftStore? sessionDraftStore,
  WorkoutAmrapDraftStore? amrapDraftStore,
  GetExerciseByIdUseCase? getExercise,
  DateTime Function()? now,
}) => ActiveWorkoutCubit(
  sessionDraftStore: sessionDraftStore ?? MemoryWorkoutSessionDraftStore(),
  amrapDraftStore: amrapDraftStore ?? MemoryWorkoutAmrapDraftStore(),
  getExercise: getExercise,
  correctSet: CorrectWorkoutSetUseCase(repository),
  executionId: 'execution-1',
  getExecution: GetWorkoutExecutionUseCase(repository),
  completeSet: CompleteWorkoutSetUseCase(repository),
  completeAmrap: CompleteAmrapBlockUseCase(repository),
  skipSet: SkipWorkoutSetUseCase(repository),
  finishExecution: FinishWorkoutExecutionUseCase(repository),
  finishWithoutFullRecording: FinishWorkoutWithoutFullRecordingUseCase(
    repository,
  ),
  abandonExecution: AbandonWorkoutExecutionUseCase(repository),
  discardExecution: DiscardWorkoutExecutionUseCase(repository),
  getPendingMutationCount: GetPendingWorkoutMutationCountUseCase(repository),
  timerStore: timerStore ?? _TimerStore(),
  cueService: cueService ?? _CueService(),
  now: now ?? _restTestClock(),
);

DateTime Function() _restTestClock() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  if (!binding.inTest) return DateTime.now;
  final wallOrigin = DateTime.now();
  final clock = binding.clock;
  final origin = clock.now();
  return () => wallOrigin.add(clock.now().difference(origin));
}

class _LockScreen implements WorkoutLockScreen {
  WorkoutLockScreenSnapshot? visible;
  int shown = 0;

  @override
  Future<bool> show(WorkoutLockScreenSnapshot snapshot) async {
    visible = snapshot;
    shown++;
    return true;
  }

  @override
  Future<void> clear(String executionId) async {
    if (visible?.executionId == executionId) visible = null;
  }
}

class _Repository implements WorkoutRepository {
  int unrecordedFinishAttempts = 0;
  Completer<void>? unrecordedGate;
  WorkoutMutationDisposition unrecordedDisposition =
      WorkoutMutationDisposition.synced;
  @override
  Future<WorkoutMutationDisposition> finishWithoutFullRecording(
    String executionId,
  ) async {
    unrecordedFinishAttempts++;
    await unrecordedGate?.future;
    if (failFinish) throw StateError('Sin conexión');
    execution = execution.copyWith(
      status: WorkoutExecutionStatus.completed,
      completedWithoutFullRecording: true,
      completedAt: DateTime.now().toUtc(),
      resultSource: WorkoutResultSource.manual,
    );
    if (unrecordedDisposition == WorkoutMutationDisposition.queued) {
      pendingMutationCount++;
    }
    return unrecordedDisposition;
  }

  WorkoutExecution execution = _execution();
  WorkoutSetResultInput? lastSetResult;
  int amrapAttempts = 0;
  bool failAmrap = false;
  bool failReadAfterAmrap = false;
  bool failPendingAfterAmrap = false;
  int finishAttempts = 0;
  bool failReadAfterFinish = false;
  bool failPendingAfterFinish = false;
  bool failFinish = false;
  bool failAbandonment = false;
  int correctionCount = 0;
  bool failCorrection = false;
  int abandonAttempts = 0;
  int discardAttempts = 0;
  bool failDiscard = false;
  bool failExecutionRead = false;
  bool executionMissing = false;
  Future<void> Function()? discardResponse;

  @override
  Future<void> discardExecution(String executionId) async {
    discardAttempts++;
    if (failDiscard) throw StateError('Sin conexión');
    await discardResponse?.call();
  }

  int pendingMutationCount = 0;
  WorkoutMutationDisposition abandonmentDisposition =
      WorkoutMutationDisposition.synced;

  @override
  Future<WorkoutExecution?> getExecution(String executionId) async {
    if (failExecutionRead) throw StateError('Sin conexión');
    if (executionMissing) return null;
    if (failReadAfterFinish && finishAttempts > 0) {
      throw StateError('Lectura fallida');
    }
    if (failReadAfterAmrap && amrapAttempts > 0) {
      throw StateError('Lectura fallida');
    }
    return execution;
  }

  @override
  Future<WorkoutMutationDisposition> completeSet(
    WorkoutSetResultInput result,
  ) async {
    lastSetResult = result;
    execution = execution.copyWith(
      sets: execution.sets
          .map(
            (set) => set.id == result.resultId
                ? set.copyWith(
                    status: WorkoutSetStatus.completed,
                    actualReps: result.actualReps,
                    actualDistanceMeters: result.actualDistanceMeters,
                    actualLoadKg: result.actualLoadKg,
                  )
                : set,
          )
          .toList(),
    );
    return WorkoutMutationDisposition.synced;
  }

  @override
  Future<WorkoutMutationDisposition> completeAmrap(
    WorkoutAmrapResultInput result,
  ) async {
    amrapAttempts++;
    if (failAmrap) throw StateError('Guardado fallido');
    final completedAt = DateTime.utc(2026, 9, 21, 20, 10);
    execution = execution.copyWith(
      sets: execution.sets
          .map(
            (set) => set.blockOrder == result.blockOrder
                ? set.copyWith(
                    status: WorkoutSetStatus.completed,
                    completedAt: completedAt,
                  )
                : set,
          )
          .toList(),
      amrapResults: [
        WorkoutAmrapResult(
          blockOrder: result.blockOrder,
          completedRounds: result.completedRounds,
          partialItemOrder: result.partialItemOrder,
          partialReps: result.partialReps,
          completedAt: completedAt,
        ),
      ],
    );
    return WorkoutMutationDisposition.synced;
  }

  @override
  Future<WorkoutMutationDisposition> skipSet(String resultId) async {
    execution = execution.copyWith(
      sets: execution.sets
          .map(
            (set) => set.id == resultId
                ? set.copyWith(status: WorkoutSetStatus.skipped)
                : set,
          )
          .toList(),
    );
    return WorkoutMutationDisposition.synced;
  }

  @override
  Future<WorkoutMutationDisposition> abandonExecution(
    String executionId,
    WorkoutAbandonmentReason reason,
  ) async {
    abandonAttempts++;
    if (failAbandonment) throw StateError('Fallo simulado de guardado');
    if (abandonmentDisposition == WorkoutMutationDisposition.queued) {
      pendingMutationCount++;
    } else {
      execution = execution.copyWith(
        status: WorkoutExecutionStatus.abandoned,
        abandonmentReason: reason,
        completedAt: DateTime.utc(2026, 10, 8, 17, 30),
      );
    }
    return abandonmentDisposition;
  }

  @override
  Future<int> getPendingMutationCount() async {
    if (failPendingAfterFinish && finishAttempts > 0) {
      throw StateError('Disco fallido');
    }
    if (failPendingAfterAmrap && amrapAttempts > 0) {
      throw StateError('Disco fallido');
    }
    return pendingMutationCount;
  }

  @override
  Future<void> correctSet(WorkoutSetCorrectionInput correction) async {
    if (failCorrection) throw StateError('Sin conexión');
    correctionCount++;
    execution = execution.copyWith(
      sets: execution.sets
          .map(
            (set) => set.id != correction.resultId
                ? set
                : set.copyWith(
                    replaceResult: true,
                    actualReps: correction.actualReps,
                    actualRir: correction.actualRir,
                    actualRpe: correction.actualRpe,
                  ),
          )
          .toList(),
    );
  }

  @override
  Future<WorkoutMutationDisposition> finishExecution(
    String executionId, {
    required int finalRpe,
    String? notes,
    int? averageHeartRateBpm,
    int? maxHeartRateBpm,
    WorkoutResultSource resultSource = WorkoutResultSource.manual,
  }) async {
    finishAttempts++;
    if (failFinish) throw StateError('Cierre rechazado');
    execution = execution.copyWith(
      status: WorkoutExecutionStatus.completed,
      finalRpe: finalRpe,
    );
    return WorkoutMutationDisposition.synced;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingClearDraftStore extends MemoryWorkoutSessionDraftStore {
  bool failClear = false;
  @override
  Future<void> clear(String executionId) async {
    if (failClear) throw StateError('Disco lleno');
    await super.clear(executionId);
  }
}

class _FailingTabataDraftStore extends MemoryWorkoutSessionDraftStore {
  bool failWrite = true;
  @override
  Future<void> write(
    String executionId,
    Map<String, WorkoutSessionSetDraft> drafts,
  ) async {
    if (failWrite) throw StateError('Disco lleno');
    await super.write(executionId, drafts);
  }
}

WorkoutExecution _tabataExecution() => _execution().copyWith(
  sets: List.generate(
    8,
    (i) => WorkoutExecutionSet(
      id: 'tabata-$i',
      blockOrder: 0,
      blockName: 'Tabata',
      blockFormat: WorkoutBlockFormat.tabata,
      itemOrder: i,
      exerciseId: 'exercise-1',
      exerciseName: 'Sentadillas',
      setOrder: 0,
      targetDurationSeconds: 20,
      targetLoadKg: 5,
      targetRpe: 7,
      restAfterSeconds: 10,
      status: WorkoutSetStatus.pending,
    ),
  ),
);

WorkoutExecution _execution({
  bool allowUnrecorded = false,
  String templateName = 'EMOM de fuerza',
  WorkoutBlockFormat format = WorkoutBlockFormat.emom,
}) => WorkoutExecution(
  canFinishWithoutFullRecording: allowUnrecorded,
  id: 'execution-1',
  templateId: 'template-1',
  templateName: templateName,
  templateVersion: 1,
  status: WorkoutExecutionStatus.inProgress,
  startedAt: DateTime.utc(2026, 9, 21, 20),
  sets: [
    WorkoutExecutionSet(
      id: 'set-1',
      blockOrder: 0,
      blockName: 'EMOM',
      blockFormat: format,
      itemOrder: 0,
      exerciseId: 'exercise-1',
      exerciseName: 'Dominadas',
      setOrder: 0,
      targetReps: 8,
      restAfterSeconds: 60,
      status: WorkoutSetStatus.pending,
    ),
    WorkoutExecutionSet(
      id: 'set-2',
      blockOrder: 0,
      blockName: 'EMOM',
      blockFormat: format,
      itemOrder: 0,
      exerciseId: 'exercise-1',
      exerciseName: 'Dominadas',
      setOrder: 1,
      targetReps: 8,
      restAfterSeconds: 60,
      status: WorkoutSetStatus.pending,
    ),
  ],
);

WorkoutExecution _amrapExecution({bool allowUnrecorded = false}) =>
    WorkoutExecution(
      canFinishWithoutFullRecording: allowUnrecorded,
      id: 'execution-1',
      templateId: 'template-1',
      templateName: 'AMRAP de fuerza',
      templateVersion: 1,
      status: WorkoutExecutionStatus.inProgress,
      startedAt: DateTime.utc(2026, 9, 21, 20),
      sets: const [
        WorkoutExecutionSet(
          id: 'set-1',
          blockOrder: 0,
          blockName: 'Trabajo principal',
          blockFormat: WorkoutBlockFormat.amrap,
          blockTimeCapSeconds: 600,
          itemOrder: 0,
          exerciseId: 'exercise-1',
          exerciseName: 'Dominadas',
          setOrder: 0,
          targetReps: 10,
          restAfterSeconds: 0,
          status: WorkoutSetStatus.pending,
        ),
        WorkoutExecutionSet(
          id: 'set-2',
          blockOrder: 0,
          blockName: 'Trabajo principal',
          blockFormat: WorkoutBlockFormat.amrap,
          blockTimeCapSeconds: 600,
          itemOrder: 1,
          exerciseId: 'exercise-2',
          exerciseName: 'Flexiones',
          setOrder: 0,
          targetReps: 8,
          restAfterSeconds: 0,
          status: WorkoutSetStatus.pending,
        ),
      ],
    );

class _TimerStore implements WorkoutTimerStore {
  _TimerStore([this.snapshot]);

  WorkoutTimerSnapshot? snapshot;
  bool failClear = false;

  @override
  Future<void> clear(String timerId) async {
    if (failClear) throw StateError('Disco lleno');
    snapshot = null;
  }

  @override
  Future<WorkoutTimerSnapshot?> read(String timerId) async => snapshot;

  @override
  Future<void> write(String timerId, WorkoutTimerSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}

class _CueService implements WorkoutCueService {
  bool offerPermission = false;
  int permissionChecks = 0;
  @override
  Future<bool> shouldOfferHapticsPermission() async {
    permissionChecks++;
    return offerPermission;
  }

  @override
  Future<void> markHapticsPermissionOffered() async => offerPermission = false;
  @override
  Future<bool> requestHapticsPermission() async => true;
  final cues = <WorkoutCue>[];

  @override
  Future<void> prepare() async {}

  @override
  Future<bool> previewSound() async => true;
  @override
  Future<bool> previewHaptics() async => true;
  @override
  WorkoutCuePreferences get preferences => const WorkoutCuePreferences();

  @override
  Future<void> savePreferences(WorkoutCuePreferences preferences) async {}

  @override
  Future<void> signal(WorkoutCue cue) async => cues.add(cue);
}

class _AmrapExercises implements ExerciseRepository {
  @override
  Future<ExerciseEntity?> getExerciseById(String id) async => ExerciseEntity(
    id: id,
    name: id,
    thumbnailUrl: 'https://example.invalid/$id.png',
    muscleGroups: const ['Core'],
    equipment: const [],
    difficulty: 'inicial',
    exerciseType: 'repeticiones',
    isPublic: false,
    origin: ExerciseOrigin.user,
    createdBy: 'owner',
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import 'dart:async';

import 'package:entrenaop/core/navigation/app_back_gesture.dart';
import 'package:entrenaop/core/router/material_app_route.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';

import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_cue_service.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_timer_store.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_state.dart';
import 'package:entrenaop/features/workouts/presentation/pages/active_workout_page.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_set_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';

void main() {
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
      final discard = find.widgetWithText(TextButton, 'Salir sin guardar').last;
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
      final notes = find.widgetWithText(
        TextField,
        '¿Cómo te has sentido? (opcional)',
      );
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Conservar si falla');
      Future<void> open() async {
        final button = find.widgetWithText(TextButton, 'Salir sin guardar');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await open();
      await tester.tap(find.text('Seguir aquí'));
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
        await tester.tap(find.text('Confirmar abandono'));
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
      final notes = find.widgetWithText(
        TextField,
        '¿Cómo te has sentido? (opcional)',
      );
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Borrador que quiero conservar');
      await _chooseExitAbandonment(tester);
      await tester.tap(find.text('Seguir entrenando'));
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
      await tester.tap(find.text('Confirmar abandono'));
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
      await tester.tap(find.text('Confirmar abandono'));
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
    final abandon = find.text('Abandonar y conservar lo realizado');
    await tester.ensureVisible(abandon);
    await tester.pumpAndSettle();
    await tester.tap(abandon);
    await tester.pumpAndSettle();
    expect(find.text('Abandonar sesión'), findsOneWidget);
    await tester.tap(find.text('Seguir entrenando'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/session');
    expect(tester.takeException(), isNull);
  });

  for (final (seconds, expectedText) in [
    (20, '0:20'),
    (90, '1:30'),
    (3601, '60:01'),
  ]) {
    testWidgets(
      'el tiempo inicial de $seconds s se puede confirmar sin reescribir',
      (tester) async {
        final repository = _Repository()..execution = _timedExecution(seconds);
        await _mountSession(tester, repository);
        final field = find.widgetWithText(
          TextFormField,
          'Tiempo realizado (min:seg)',
        );
        expect(
          tester.widget<TextFormField>(field).controller!.text,
          expectedText,
        );
        final save = find.text('Guardar serie');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
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
      await _mountSession(tester, repository);
      final timer = tester.widget<WorkoutSetCountdown>(
        find.byType(WorkoutSetCountdown),
      );
      timer.onElapsedChanged(20);
      await tester.pump();
      final field = find.widgetWithText(
        TextFormField,
        'Tiempo realizado (min:seg)',
      );
      expect(tester.widget<TextFormField>(field).controller!.text, '0:20');
      final save = find.text('Guardar serie');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.lastSetResult?.actualDurationSeconds, 20);
      expect(find.text('Introduce un tiempo válido'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('escribir 20 manualmente guarda veinte segundos', (tester) async {
    final repository = _Repository()..execution = _timedExecution(90);
    await _mountSession(tester, repository);
    final field = find.widgetWithText(
      TextFormField,
      'Tiempo realizado (min:seg)',
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, '20');
    expect(tester.widget<TextFormField>(field).controller!.text, '0:20');
    final save = find.text('Guardar serie');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.lastSetResult?.actualDurationSeconds, 20);
    expect(tester.takeException(), isNull);
  });

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
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar abandono'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Seguir entrenando'));
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
      expect(find.text('Abandonar la sesión definitivamente'), findsNothing);

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
      final notes = find.widgetWithText(
        TextField,
        '¿Cómo te has sentido? (opcional)',
      );
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
    expect(find.text('Sesión en curso'), findsOneWidget);
    expect(cubit.state.execution, isNotNull);
  });

  for (final bySwipe in [false, true]) {
    testWidgets('salir y retomar conserva series, gesto $bySwipe', (
      tester,
    ) async {
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
            EntrenaTheme.dark.copyWith(platform: TargetPlatform.iOS),
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
      await tester.tap(find.text('Seguir aquí'));
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
      expect(find.text('Guardar serie'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  Future<(_Repository, ActiveWorkoutCubit)> mountEffortSet(
    WidgetTester tester,
  ) async {
    final repository = _Repository();
    repository.execution = repository.execution.copyWith(
      sets: const [
        WorkoutExecutionSet(
          id: 'effort-set',
          blockOrder: 0,
          blockName: 'Trabajo',
          itemOrder: 0,
          exerciseId: 'push-up',
          exerciseName: 'Flexiones',
          setOrder: 0,
          targetReps: 8,
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
    final save = find.text('Guardar serie');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.lastSetResult?.actualReps, 8);
    expect(repository.lastSetResult?.actualRir, isNull);
    expect(repository.lastSetResult?.actualRpe, isNull);
  });
  testWidgets(
    'RIR cero declarado llega al repositorio y no se sustituye por el objetivo',
    (tester) async {
      final (repository, _) = await mountEffortSet(tester);
      final field = find.widgetWithText(
        DropdownButtonFormField<double>,
        'RIR real',
      );
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.text('0').last);
      await tester.pumpAndSettle();
      final save = find.text('Guardar serie');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.lastSetResult?.actualRir, 0);
      expect(repository.lastSetResult?.actualRpe, isNull);
    },
  );
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
}

WorkoutExecution _executionWithStatuses(List<WorkoutSetStatus> statuses) {
  final execution = _execution();
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
}) async {
  final cubit = _cubit(repository);
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
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
    ),
  );
  router.push('/session');
  await tester.pumpAndSettle();
  return (cubit, router);
}

Future<void> _chooseExitAbandonment(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Salir de la sesión'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Abandonar y conservar lo realizado'));
  await tester.pumpAndSettle();
}

Future<void> _openAbandonment(WidgetTester tester) async {
  final abandon = find.text('Abandonar la sesión definitivamente');
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
  await tester.tap(find.text('Confirmar abandono'));
  await tester.pumpAndSettle();
}

ActiveWorkoutCubit _cubit(
  _Repository repository, {
  _TimerStore? timerStore,
  _CueService? cueService,
}) => ActiveWorkoutCubit(
  executionId: 'execution-1',
  getExecution: GetWorkoutExecutionUseCase(repository),
  completeSet: CompleteWorkoutSetUseCase(repository),
  completeAmrap: CompleteAmrapBlockUseCase(repository),
  skipSet: SkipWorkoutSetUseCase(repository),
  finishExecution: FinishWorkoutExecutionUseCase(repository),
  abandonExecution: AbandonWorkoutExecutionUseCase(repository),
  discardExecution: DiscardWorkoutExecutionUseCase(repository),
  getPendingMutationCount: GetPendingWorkoutMutationCountUseCase(repository),
  timerStore: timerStore ?? _TimerStore(),
  cueService: cueService ?? _CueService(),
);

class _Repository implements WorkoutRepository {
  WorkoutExecution execution = _execution();
  WorkoutSetResultInput? lastSetResult;
  bool failAbandonment = false;
  int abandonAttempts = 0;
  int discardAttempts = 0;
  bool failDiscard = false;
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
  Future<WorkoutExecution?> getExecution(String executionId) async => execution;

  @override
  Future<WorkoutMutationDisposition> completeSet(
    WorkoutSetResultInput result,
  ) async {
    lastSetResult = result;
    execution = execution.copyWith(
      sets: execution.sets
          .map(
            (set) => set.id == result.resultId
                ? set.copyWith(status: WorkoutSetStatus.completed)
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
  Future<int> getPendingMutationCount() async => pendingMutationCount;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WorkoutExecution _execution() => WorkoutExecution(
  id: 'execution-1',
  templateId: 'template-1',
  templateName: 'EMOM de fuerza',
  templateVersion: 1,
  status: WorkoutExecutionStatus.inProgress,
  startedAt: DateTime.utc(2026, 9, 21, 20),
  sets: const [
    WorkoutExecutionSet(
      id: 'set-1',
      blockOrder: 0,
      blockName: 'EMOM',
      blockFormat: WorkoutBlockFormat.emom,
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
      blockFormat: WorkoutBlockFormat.emom,
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

WorkoutExecution _amrapExecution() => WorkoutExecution(
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

  @override
  Future<void> clear(String timerId) async => snapshot = null;

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

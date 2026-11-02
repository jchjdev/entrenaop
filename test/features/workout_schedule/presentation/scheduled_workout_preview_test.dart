import 'dart:async';

import 'package:entrenaop/features/pro/domain/pro_access.dart';

import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout_preview.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/scheduled_workout_preview_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/usecases/scheduled_workout_preview_usecases.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/scheduled_workout_preview_cubit.dart';
import 'package:entrenaop/features/workout_schedule/presentation/pages/scheduled_workout_preview_page.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/performance_set.dart';

void main() {
  test(
    'Free conserva la pauta pero no puede solicitar otro inicio adaptativo',
    () async {
      final repository = _PreviewRepository()
        ..preview = scheduledWorkoutPreviewFixture(
          proRequired: true,
          source: ScheduledWorkoutSource.algorithm,
        );
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.preview!.workout.blocks, isNotEmpty);
      expect(cubit.state.canStart, isFalse);
      await cubit.start();
      expect(repository.startedRevisions, isEmpty);
      expect(cubit.state.preview!.revision, 'revision-3');
    },
  );

  test('retirar Pro entre consulta e inicio bloquea reintentos y recuperarlo no inicia solo', () async {
    final repository = _PreviewRepository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    repository.onStart = (_) async => throw const ProAccessDenied(
      ProRestriction.adaptiveProgram,
      'Necesitas Pro para empezar otro entrenamiento adaptativo.',
    );
    await cubit.start();
    expect(cubit.state.preview!.proRequired, isTrue);
    expect(cubit.state.canStart, isFalse);
    expect(cubit.state.executionId, isNull);
    expect(cubit.state.preview!.revision, 'revision-3');
    await cubit.start();
    expect(repository.startedRevisions, hasLength(1));
    repository.onStart = null;
    await cubit.load();
    expect(cubit.state.canStart, isTrue);
    expect(repository.startedRevisions, hasLength(1));
    await cubit.start();
    expect(repository.startedRevisions, hasLength(2));
    expect(cubit.state.executionId, 'execution');
  });

  test(
    'una ejecución adaptativa abierta antes de perder Pro permite continuar',
    () async {
      final repository = _PreviewRepository()
        ..preview = scheduledWorkoutPreviewFixture(
          source: ScheduledWorkoutSource.algorithm,
          status: ScheduledWorkoutStatus.inProgress,
        );
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.canStart, isTrue);
      await cubit.start();
      expect(cubit.state.executionId, 'execution');
    },
  );

  testWidgets(
    'vista previa Free sigue visible y volver de Pro actualiza sin empezar',
    (tester) async {
      final repository = _PreviewRepository()
        ..preview = scheduledWorkoutPreviewFixture(
          proRequired: true,
          source: ScheduledWorkoutSource.algorithm,
        );
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      final router = _router(cubit, direct: true);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('scheduled-preview-start')),
        findsNothing,
      );
      expect(find.text('Activa Pro para entrenar con este plan.'), findsOneWidget);
      await tester.tap(find.text('Ver Pro'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/pro');
      expect(router.state.uri.queryParameters['goal'], 'goal');
      repository.preview = scheduledWorkoutPreviewFixture(
        source: ScheduledWorkoutSource.algorithm,
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('scheduled-preview-start')),
        findsOneWidget,
      );
      expect(repository.startedRevisions, isEmpty);
      expect(repository.lookups, hasLength(2));
    },
  );

  testWidgets(
    'consulta Free mantiene acciones accesibles a 320 px y texto 2×',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 480);
      addTearDown(tester.view.reset);
      final repository = _PreviewRepository()
        ..preview = scheduledWorkoutPreviewFixture(
          proRequired: true,
          source: ScheduledWorkoutSource.algorithm,
        );
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      final router = _router(cubit, direct: true);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: EntrenaTheme.dark,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Ver Pro').hitTestable(), findsOneWidget);
      expect(find.text('Actualizar acceso').hitTestable(), findsOneWidget);
      expect(repository.startedRevisions, isEmpty);
    },
  );

  test('consultar y reintentar no inicia ni altera la pauta', () async {
    final repository = _PreviewRepository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    repository.onGet = () async => throw StateError('Sin conexión');
    await cubit.load();
    expect(cubit.state.status, ScheduledWorkoutPreviewStatus.failure);
    expect(cubit.state.preview, isNull);
    expect(repository.startedRevisions, isEmpty);
    repository.onGet = null;
    await cubit.load();
    expect(cubit.state.preview, repository.preview);
    expect(cubit.state.preview!.workout.version, 3);
    expect(repository.lookups, ['scheduled', 'scheduled']);
    expect(repository.startedRevisions, isEmpty);
  });

  test(
    'doble pulsación usa una sola llamada con la revisión consultada',
    () async {
      final pending = Completer<String>();
      final repository = _PreviewRepository()..onStart = (_) => pending.future;
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      final first = cubit.start();
      await cubit.start();
      expect(repository.startedRevisions, ['revision-3']);
      expect(cubit.state.status, ScheduledWorkoutPreviewStatus.starting);
      pending.complete('execution');
      await first;
      await cubit.start();
      expect(repository.startedRevisions, ['revision-3']);
      expect(cubit.state.executionId, 'execution');
    },
  );

  test(
    'una edición refresca lo pautado y requiere otro gesto para comenzar',
    () async {
      final repository = _PreviewRepository();
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      repository.onStart = (_) async {
        repository.preview = scheduledWorkoutPreviewFixture(version: 4);
        throw const ScheduledWorkoutPreviewChanged();
      };
      await cubit.start();
      expect(cubit.state.preview!.workout.version, 4);
      expect(cubit.state.message, contains('ha cambiado'));
      expect(cubit.state.executionId, isNull);
      expect(repository.startedRevisions, ['revision-3']);
      repository.onStart = null;
      await cubit.start();
      expect(repository.startedRevisions, ['revision-3', 'revision-4']);
      expect(cubit.state.executionId, 'execution');
    },
  );

  test(
    'un cambio que no puede refrescarse bloquea empezar la copia anterior',
    () async {
      final repository = _PreviewRepository();
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      repository.onStart = (_) async {
        repository.onGet = () async => throw StateError('Sin conexión');
        throw const ScheduledWorkoutPreviewChanged();
      };
      await cubit.start();
      expect(cubit.state.refreshRequired, isTrue);
      expect(cubit.state.canStart, isFalse);
      expect(cubit.state.message, contains('ha cambiado'));
      await cubit.start();
      expect(repository.startedRevisions, ['revision-3']);
      repository
        ..onGet = null
        ..onStart = null;
      await cubit.load();
      expect(cubit.state.canStart, isTrue);
      expect(repository.startedRevisions, ['revision-3']);
    },
  );

  test(
    'un fallo al comenzar conserva lo pautado y permite reintento explícito',
    () async {
      final repository = _PreviewRepository()
        ..onStart = (_) async => throw StateError('Diagnóstico privado');
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.start();
      expect(cubit.state.preview, repository.preview);
      expect(cubit.state.message, isNot(contains('Diagnóstico')));
      expect(cubit.state.executionId, isNull);
      repository.onStart = null;
      await cubit.start();
      expect(repository.startedRevisions, ['revision-3', 'revision-3']);
      expect(cubit.state.executionId, 'execution');
    },
  );

  test('cerrar la vista descarta una consulta tardía', () async {
    final pending = Completer<ScheduledWorkoutPreview>();
    final repository = _PreviewRepository()..onGet = () => pending.future;
    final cubit = _cubit(repository);
    final loading = cubit.load();
    await cubit.close();
    pending.complete(repository.preview);
    await loading;
    expect(cubit.state.preview, isNull);
    expect(repository.startedRevisions, isEmpty);
  });

  test(
    'un resultado recibido mientras estaba abierta no resucita la pauta',
    () async {
      final repository = _PreviewRepository();
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      repository.onStart = (_) async {
        repository.preview = scheduledWorkoutPreviewFixture(
          status: ScheduledWorkoutStatus.completed,
        );
        throw const ScheduledWorkoutPreviewChanged();
      };
      await cubit.start();
      expect(cubit.state.preview!.hasResult, isTrue);
      expect(cubit.state.canStart, isFalse);
      expect(cubit.state.executionId, isNull);
      expect(cubit.state.message, contains('ya tiene un resultado'));
      await cubit.start();
      expect(repository.startedRevisions, ['revision-3']);
    },
  );

  testWidgets('una finalización externa cambia Comenzar por Ver resultado', (
    tester,
  ) async {
    final repository = _PreviewRepository();
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    repository.onStart = (_) async {
      repository.preview = scheduledWorkoutPreviewFixture(
        status: ScheduledWorkoutStatus.completed,
      );
      throw const ScheduledWorkoutPreviewChanged();
    };
    final router = _router(cubit);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver entrenamiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scheduled-preview-start')));
    await tester.pumpAndSettle();
    expect(find.text('Comenzar entrenamiento'), findsNothing);
    expect(find.text('Ver resultado'), findsOneWidget);
    expect(find.textContaining('ya tiene un resultado'), findsOneWidget);
    expect(repository.startedRevisions, ['revision-3']);
    await tester.tap(find.text('Ver resultado'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/assessment/history/workouts/execution');
    expect(repository.startedRevisions, ['revision-3']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'iniciar protege atrás y otros destinos hasta resolver la escritura',
    (tester) async {
      final pending = Completer<String>();
      final repository = _PreviewRepository()..onStart = (_) => pending.future;
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      final router = _router(cubit);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver entrenamiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scheduled-preview-start')));
      await tester.pump();
      expect(cubit.state.status, ScheduledWorkoutPreviewStatus.starting);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(router.state.uri.path, '/plan/week/session/scheduled');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(router.state.uri.path, '/plan/week/session/scheduled');
      router.go('/plan/week?date=2026-09-23');
      await tester.pump();
      expect(router.state.uri.path, '/plan/week/session/scheduled');
      expect(repository.startedRevisions, ['revision-3']);
      pending.completeError(StateError('Sin conexión'));
      await tester.pumpAndSettle();
      expect(cubit.state.status, ScheduledWorkoutPreviewStatus.failure);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/plan/week');
      expect(repository.startedRevisions, ['revision-3']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in [(390.0, 844.0, 1.0), (320.0, 480.0, 2.0)]) {
    testWidgets(
      'consulta completa y comienzo explícito con retorno: $viewport',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(viewport.$1, viewport.$2));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _PreviewRepository();
        final cubit = _cubit(repository);
        addTearDown(cubit.close);
        await cubit.load();
        final router = _router(cubit);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            theme: EntrenaTheme.dark,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(viewport.$3)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver entrenamiento'));
        await tester.pumpAndSettle();
        expect(find.text('Entrenamiento'), findsOneWidget);
        expect(find.text('Versión 3'), findsOneWidget);
        expect(find.textContaining('Pautado · 23/09/2026'), findsOneWidget);
        expect(
          find.text('Cuida la técnica y conserva los descansos.'),
          findsOneWidget,
        );
        expect(find.textContaining('6 repeticiones'), findsOneWidget);
        expect(find.textContaining('22 kg'), findsOneWidget);
        expect(find.textContaining('RPE 8'), findsOneWidget);
        expect(
          find.textContaining('Controla la bajada y evita el rebote.'),
          findsOneWidget,
        );
        expect(find.text('Nota · Última serie diferente'), findsOneWidget);
        expect(find.textContaining('5:00–5:30/km'), findsOneWidget);
        expect(find.textContaining('recuperación andando'), findsOneWidget);
        expect(repository.startedRevisions, isEmpty);
        final start = find.byKey(const ValueKey('scheduled-preview-start'));
        final startRect = tester.getRect(start);
        await tester.ensureVisible(find.text('Carrera final'));
        await tester.pumpAndSettle();
        expect(tester.getRect(start), startRect);
        expect(startRect.bottom, lessThanOrEqualTo(viewport.$2));
        await tester.tap(start);
        await tester.pumpAndSettle();
        expect(find.text('Ejecutor execution'), findsOneWidget);
        expect(repository.startedRevisions, ['revision-3']);
        router.pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/plan/week');
        expect(router.state.uri.queryParameters['date'], '2026-09-23');
        expect(repository.startedRevisions, ['revision-3']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'entrada directa conserva el origen aunque cambie la fecha pautada',
    (tester) async {
      final repository = _PreviewRepository()
        ..preview = scheduledWorkoutPreviewFixture(
          scheduledDate: DateTime(2026, 9, 25),
        );
      final cubit = _cubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      final router = _router(cubit, direct: true);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters['date'], '2026-09-23');
      expect(repository.startedRevisions, isEmpty);
    },
  );

  testWidgets('entrada directa con error vuelve a la fecha original', (
    tester,
  ) async {
    final repository = _PreviewRepository()
      ..onGet = () async => throw StateError('Contenido retirado');
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    final router = _router(cubit, direct: true);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Comenzar entrenamiento'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/plan/week');
    expect(router.state.uri.queryParameters['date'], '2026-09-23');
    expect(repository.startedRevisions, isEmpty);
  });
}

GoRouter _router(ScheduledWorkoutPreviewCubit cubit, {bool direct = false}) {
  const path = '/plan/week/session/scheduled';
  final exits = WorkflowExitRegistry();
  return GoRouter(
    initialLocation: direct
        ? '$path?date=2026-09-23'
        : '/plan/week?date=2026-09-23',
    routes: [
      GoRoute(
        path: '/pro',
        builder: (_, _) => const Scaffold(body: Text('Oferta Pro')),
      ),
      GoRoute(
        path: '/plan/week',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('$path?date=2026-09-23'),
            child: const Text('Ver entrenamiento'),
          ),
        ),
      ),
      GoRoute(
        path: path,
        onExit: (_, state) => exits.requestExit(state.pageKey),
        builder: (_, state) => WorkflowExitScope(
          controller: exits.controller(state.pageKey),
          child: BlocProvider.value(
            value: cubit,
            child: ScheduledWorkoutPreviewPage(
              routeBase: path,
              initialDate: DateTime(2026, 9, 23),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '$path/active/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Ejecutor ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/assessment/history/workouts/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Resultado ${state.pathParameters['id']}')),
      ),
    ],
  );
}

ScheduledWorkoutPreviewCubit _cubit(_PreviewRepository repository) =>
    ScheduledWorkoutPreviewCubit(
      scheduledId: 'scheduled',
      getPreview: GetScheduledWorkoutPreviewUseCase(repository),
      startReviewed: StartReviewedScheduledWorkoutUseCase(repository),
    );

class _PreviewRepository implements ScheduledWorkoutPreviewRepository {
  ScheduledWorkoutPreview preview = scheduledWorkoutPreviewFixture();
  final lookups = <String>[];
  final startedRevisions = <String>[];
  Future<ScheduledWorkoutPreview> Function()? onGet;
  Future<String> Function(String)? onStart;

  @override
  Future<ScheduledWorkoutPreview> get(String id) async {
    lookups.add(id);
    return onGet?.call() ?? preview;
  }

  @override
  Future<String> startReviewed(String id, String revision) async {
    expect(id, 'scheduled');
    startedRevisions.add(revision);
    return onStart?.call(revision) ?? 'execution';
  }
}

ScheduledWorkoutPreview scheduledWorkoutPreviewFixture({
  int version = 3,
  ScheduledWorkoutStatus status = ScheduledWorkoutStatus.planned,
  DateTime? scheduledDate,
  bool proRequired = false,
  ScheduledWorkoutSource source = ScheduledWorkoutSource.coach,
}) => ScheduledWorkoutPreview(
  proRequired: proRequired,
  scheduled: ScheduledWorkout(
    id: 'scheduled',
    templateId: 'private',
    templateName: 'Fuerza y carrera',
    templateVersion: version,
    scheduledDate: scheduledDate ?? DateTime(2026, 9, 23),
    source: source,
    preparationGoalId: source == ScheduledWorkoutSource.algorithm
        ? 'goal'
        : null,
    status: status,
    executionId: status == ScheduledWorkoutStatus.planned ? null : 'execution',
    coachName: 'Ervi',
    coachNote: 'Cuida la técnica y conserva los descansos.',
  ),
  revision: 'revision-$version',
  workout: WorkoutTemplate(
    id: 'private',
    name: 'Fuerza y carrera',
    description: 'Pauta individual',
    estimatedDurationMinutes: 45,
    version: version,
    blocks: const [
      WorkoutBlock(
        id: 'strength',
        name: 'Fuerza pautada',
        format: WorkoutBlockFormat.straightSets,
        rounds: 1,
        restAfterSeconds: 90,
        items: [
          WorkoutItem(
            id: 'item',
            exerciseId: 'exercise',
            exerciseName: 'Sentadilla',
            notes: 'Última serie diferente',
            sets: [
              WorkoutSet(
                id: 'one',
                order: 0,
                targetReps: 8,
                targetLoadKg: 20,
                restAfterSeconds: 90,
              ),
              WorkoutSet(
                id: 'two',
                order: 1,
                targetReps: 6,
                targetLoadKg: 22,
                restAfterSeconds: 120,
              ),
              WorkoutSet(
                id: 'three',
                order: 2,
                restAfterSeconds: 120,
                performancePrescription: PerformanceSetPrescription(
                  exerciseCode: 'squat',
                  exerciseVersion: 1,
                  protocolKey: 'strength',
                  protocolVersion: 1,
                  setupKey: 'barbell',
                  measurement: 'LOAD_REPS',
                  loadMode: 'external',
                  policyVersion: 'v1',
                  targetValue: 5,
                  externalLoadKg: 30,
                  effortMode: 'rpe',
                  targetRpe: 8,
                  instructions: 'Controla la bajada y evita el rebote.',
                ),
              ),
            ],
          ),
        ],
      ),
      WorkoutBlock(
        id: 'running',
        name: 'Carrera final',
        format: WorkoutBlockFormat.running,
        rounds: 1,
        restAfterSeconds: 0,
        items: [
          WorkoutItem(
            id: 'run',
            exerciseId: runningExerciseId,
            exerciseName: 'Carrera continua',
            sets: [
              WorkoutSet(
                id: 'run-one',
                order: 0,
                targetDurationSeconds: 600,
                targetPaceMinSecondsPerKm: 300,
                targetPaceMaxSecondsPerKm: 330,
                recoveryType: RunningRecoveryType.walking,
                recoveryDurationSeconds: 30,
                restAfterSeconds: 0,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
);

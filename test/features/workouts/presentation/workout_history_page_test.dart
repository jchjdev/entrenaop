import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_history_query.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_history_detail_page.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'diez series del mismo ejercicio quedan plegadas con sus tiempos originales',
    (tester) async {
      await _pumpGroups(tester, List.generate(10, (i) => _historySet(i)));
      expect(find.text('Press banca'), findsOneWidget);
      expect(find.text('10/10 completadas'), findsOneWidget);
      expect(find.text('Realizado · 10 × 5 rep · 20 kg'), findsOneWidget);
      expect(find.textContaining('Objetivo ·'), findsNothing);
      await tester.ensureVisible(find.text('Press banca'));
      await tester.tap(find.text('Press banca'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Realizado · 5 rep · 0:04.67 · 20 kg'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Objetivo · 5 rep · 20 kg'),
        findsNWidgets(10),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'repetir un ejercicio en otra posición o bloque no mezcla sus series',
    (tester) async {
      await _pumpGroups(tester, [
        _historySet(0),
        _historySet(1),
        _historySet(0, item: 1),
        _historySet(0, block: 1),
      ]);
      expect(find.text('Press banca'), findsNWidgets(3));
      expect(find.text('2/2 completadas'), findsOneWidget);
      expect(find.text('1/1 completadas'), findsNWidgets(2));
      await _toggleAll(tester, 'Desplegar todo');
      expect(find.textContaining('Objetivo ·'), findsNWidgets(4));
      await _toggleAll(tester, 'Plegar todo');
      expect(find.textContaining('Objetivo ·'), findsNothing);
      expect(find.text('Press banca'), findsNWidgets(3));
    },
  );

  testWidgets(
    'la tarjeta resume omisiones y pendientes sin inventar kilos o uniformidad',
    (tester) async {
      await _pumpGroups(tester, [
        _historySet(0, reps: 4),
        _historySet(1, reps: 3, load: null),
        _historySet(2, status: WorkoutSetStatus.skipped),
        _historySet(3, status: WorkoutSetStatus.pending),
      ]);
      expect(
        find.text('2/4 completadas · 1 omitida · 1 pendiente'),
        findsOneWidget,
      );
      expect(find.text('Resultados variables · ver series'), findsOneWidget);
      await _toggleAll(tester, 'Desplegar todo');
      expect(
        find.textContaining('Realizado · 4 rep · 0:04.67 · 20 kg'),
        findsOneWidget,
      );
      expect(find.text('Realizado · 3 rep · 0:05.67'), findsOneWidget);
      expect(find.text('Serie omitida'), findsOneWidget);
      expect(find.text('No realizada'), findsOneWidget);
    },
  );

  testWidgets(
    'carrera conserva sus tramos y no ofrece plegado de series de fuerza',
    (tester) async {
      await _pumpGroups(tester, [
        _historySet(0, format: WorkoutBlockFormat.running),
        _historySet(1, format: WorkoutBlockFormat.running),
      ]);
      expect(find.textContaining('Objetivo ·'), findsNWidgets(2));
      expect(find.text('Desplegar todo'), findsNothing);
    },
  );

  for (final format in [
    WorkoutBlockFormat.superset,
    WorkoutBlockFormat.tabata,
  ]) {
    testWidgets(
      'historial $format a 320 px y texto doble mantiene acceso a todas las series',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pumpGroups(tester, [
          for (var item = 0; item < 2; item++)
            for (var i = 0; i < 3; i++)
              _historySet(i, item: item, format: format),
        ], scale: 2);
        await _toggleAll(tester, 'Desplegar todo');
        await tester.scrollUntilVisible(
          find.textContaining('Objetivo ·').last,
          200,
        );
        expect(tester.takeException(), isNull);
        await _toggleAll(tester, 'Plegar todo');
        expect(find.textContaining('Objetivo ·'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'objetivo, resultado y total conservan minutos y segundos legibles',
    (tester) async {
      final cubit = WorkoutHistoryDetailCubit(
        executionId: 'execution-1',
        getExecution: GetWorkoutExecutionUseCase(_ClockRepository()),
        correctSet: CorrectWorkoutSetUseCase(_ClockRepository()),
      );
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const WorkoutHistoryDetailPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('13:23'), findsWidgets);
      await _toggleAll(tester, 'Desplegar todo');
      await tester.scrollUntilVisible(
        find.textContaining('Realizado ·').last,
        200,
      );
      expect(find.text('Realizado · 01:29'), findsNWidgets(2));
      expect(find.textContaining('Objetivo · 01:30'), findsOneWidget);
      expect(find.textContaining('803 s'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('el historial de sesiones cabe en una pantalla móvil', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository();
    final cubit = WorkoutHistoryCubit(
      getHistory: GetWorkoutHistoryUseCase(repository),
    );
    await cubit.load();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutHistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evolución'), findsOneWidget);
    expect(find.text('Evaluaciones y controles'), findsOneWidget);
    expect(find.text('Historial de entrenamientos'), findsOneWidget);
    expect(find.text('Sesión inicial'), findsOneWidget);
    expect(find.text('1 completadas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el detalle distingue objetivo y resultado real', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository();
    final cubit = WorkoutHistoryDetailCubit(
      executionId: 'execution-1',
      getExecution: GetWorkoutExecutionUseCase(repository),
      correctSet: CorrectWorkoutSetUseCase(repository),
    );
    await cubit.load();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: BlocProvider.value(
          value: cubit,
          child: const WorkoutHistoryDetailPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _toggleAll(tester, 'Desplegar todo');
    expect(find.text('Objetivo · 10 rep'), findsOneWidget);
    expect(find.text('Realizado · 8 rep · RIR 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final duration in [false, true]) {
    testWidgets(
      'corregir otro dato conserva RIR 2.5 antiguo: duración=$duration',
      (tester) async {
        final repository = _CorrectionRepository(duration);
        final cubit = WorkoutHistoryDetailCubit(
          executionId: 'execution-1',
          getExecution: GetWorkoutExecutionUseCase(repository),
          correctSet: CorrectWorkoutSetUseCase(repository),
        );
        await cubit.load();
        addTearDown(cubit.close);
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: cubit,
              child: const WorkoutHistoryDetailPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _toggleAll(tester, 'Desplegar todo');
        await tester.ensureVisible(find.byTooltip('Corregir resultado'));
        await tester.tap(find.byTooltip('Corregir resultado'));
        await tester.pumpAndSettle();
        expect(find.text('RIR real'), duration ? findsNothing : findsOneWidget);
        final reason = find.widgetWithText(TextFormField, 'Motivo');
        await tester.ensureVisible(reason);
        await tester.enterText(reason, 'Corregir anotación');
        await tester.tap(find.text('Guardar corrección'));
        await tester.pumpAndSettle();
        expect(repository.lastCorrection?.actualRir, 2.5);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final partialReps in [0, 3]) {
    testWidgets(
      'el detalle conserva el agregado AMRAP con $partialReps repeticiones parciales',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _AmrapRepository(partialReps: partialReps);
        final cubit = WorkoutHistoryDetailCubit(
          executionId: 'execution-amrap',
          getExecution: GetWorkoutExecutionUseCase(repository),
          correctSet: CorrectWorkoutSetUseCase(repository),
        );
        await cubit.load();
        addTearDown(cubit.close);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: BlocProvider.value(
              value: cubit,
              child: const WorkoutHistoryDetailPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('5 vueltas completas'), findsOneWidget);
        expect(
          find.text(
            'En la siguiente vuelta: completaste Dominadas; $partialReps repeticiones de Flexiones.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Realizado ·'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _toggleAll(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _pumpGroups(
  WidgetTester tester,
  List<WorkoutExecutionSet> sets, {
  double scale = 1,
}) async {
  final repository = _GroupedHistoryRepository(sets);
  final cubit = WorkoutHistoryDetailCubit(
    executionId: 'history-groups',
    getExecution: GetWorkoutExecutionUseCase(repository),
    correctSet: CorrectWorkoutSetUseCase(repository),
  );
  addTearDown(cubit.close);
  await cubit.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: BlocProvider.value(
        value: cubit,
        child: const WorkoutHistoryDetailPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

WorkoutExecutionSet _historySet(
  int order, {
  int block = 0,
  int item = 0,
  int reps = 5,
  double? load = 20,
  WorkoutSetStatus status = WorkoutSetStatus.completed,
  WorkoutBlockFormat format = WorkoutBlockFormat.straightSets,
}) => WorkoutExecutionSet(
  id: 'set-$block-$item-$order',
  blockOrder: block,
  blockName: 'Bloque ${block + 1}',
  blockFormat: format,
  itemOrder: item,
  exerciseId: 'bench',
  exerciseName: 'Press banca',
  setOrder: order,
  targetReps: 5,
  targetLoadKg: 20,
  restAfterSeconds: 60,
  status: status,
  actualReps: status == WorkoutSetStatus.completed ? reps : null,
  actualLoadKg: status == WorkoutSetStatus.completed ? load : null,
  actualDurationSeconds: status == WorkoutSetStatus.completed
      ? 5 + order
      : null,
  observedDurationSeconds: status == WorkoutSetStatus.completed
      ? 4.665 + order
      : null,
  resultSource: WorkoutResultSource.device,
);

class _GroupedHistoryRepository extends _Repository {
  _GroupedHistoryRepository(this.sets);
  final List<WorkoutExecutionSet> sets;
  @override
  Future<WorkoutExecution?> getExecution(String executionId) async =>
      execution.copyWith(sets: sets);
}

class _AmrapRepository extends _Repository {
  _AmrapRepository({int partialReps = 3})
    : amrapExecution = WorkoutExecution(
        id: 'execution-amrap',
        templateId: 'template-amrap',
        templateName: 'AMRAP de fuerza',
        templateVersion: 1,
        status: WorkoutExecutionStatus.completed,
        startedAt: DateTime(2026, 9, 21, 17),
        completedAt: DateTime(2026, 9, 21, 17, 10),
        sets: const [
          WorkoutExecutionSet(
            id: 'amrap-1',
            blockOrder: 0,
            blockName: 'Trabajo principal',
            blockFormat: WorkoutBlockFormat.amrap,
            blockTimeCapSeconds: 600,
            itemOrder: 0,
            exerciseId: 'pull-ups',
            exerciseName: 'Dominadas',
            setOrder: 0,
            targetReps: 8,
            restAfterSeconds: 0,
            status: WorkoutSetStatus.completed,
          ),
          WorkoutExecutionSet(
            id: 'amrap-2',
            blockOrder: 0,
            blockName: 'Trabajo principal',
            blockFormat: WorkoutBlockFormat.amrap,
            blockTimeCapSeconds: 600,
            itemOrder: 1,
            exerciseId: 'push-ups',
            exerciseName: 'Flexiones',
            setOrder: 0,
            targetReps: 12,
            restAfterSeconds: 0,
            status: WorkoutSetStatus.completed,
          ),
        ],
        amrapResults: [
          WorkoutAmrapResult(
            blockOrder: 0,
            completedRounds: 5,
            partialItemOrder: 1,
            partialReps: partialReps,
            completedAt: DateTime(2026, 9, 21, 17, 10),
          ),
        ],
      );

  final WorkoutExecution amrapExecution;

  @override
  Future<WorkoutExecution?> getExecution(String executionId) async =>
      amrapExecution;
}

class _Repository implements WorkoutRepository {
  @override
  Future<void> discardExecution(String executionId) async =>
      throw UnimplementedError();
  final execution = WorkoutExecution(
    id: 'execution-1',
    templateId: 'template-1',
    templateName: 'Sesión inicial',
    templateVersion: 1,
    status: WorkoutExecutionStatus.completed,
    startedAt: DateTime(2026, 9, 20, 17),
    completedAt: DateTime(2026, 9, 20, 17, 30),
    finalRpe: 7,
    sets: const [
      WorkoutExecutionSet(
        id: 'set-1',
        blockOrder: 0,
        blockName: 'Fuerza',
        itemOrder: 0,
        exerciseId: 'push-ups',
        exerciseName: 'Flexiones',
        setOrder: 0,
        targetReps: 10,
        restAfterSeconds: 60,
        status: WorkoutSetStatus.completed,
        actualReps: 8,
        actualRir: 2,
      ),
    ],
  );

  @override
  Future<WorkoutExecution?> getExecution(String executionId) async => execution;

  @override
  Future<List<WorkoutExecution>> getExecutionHistory({
    WorkoutHistoryQuery query = const WorkoutHistoryQuery(),
  }) async => [execution];

  @override
  Future<WorkoutMutationDisposition> abandonExecution(
    String executionId,
    WorkoutAbandonmentReason reason,
  ) async => WorkoutMutationDisposition.synced;

  @override
  Future<WorkoutMutationDisposition> completeSet(
    WorkoutSetResultInput result,
  ) async => WorkoutMutationDisposition.synced;

  @override
  Future<WorkoutMutationDisposition> completeAmrap(
    WorkoutAmrapResultInput result,
  ) async => WorkoutMutationDisposition.synced;

  @override
  Future<void> correctSet(WorkoutSetCorrectionInput correction) async {}

  @override
  Future<WorkoutMutationDisposition> finishExecution(
    String executionId, {
    required int finalRpe,
    String? notes,
    int? averageHeartRateBpm,
    int? maxHeartRateBpm,
    WorkoutResultSource resultSource = WorkoutResultSource.manual,
  }) async => WorkoutMutationDisposition.synced;

  @override
  Future<int> getPendingMutationCount() async => 0;

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async => null;

  @override
  Future<List<WorkoutTemplateSummary>> getPublicTemplates() async => const [];

  @override
  Future<List<WorkoutTemplateSummary>> getPersonalTemplates() async => const [];

  @override
  Future<String> createPersonalTemplate(CreatePersonalWorkoutInput input) =>
      throw UnimplementedError();

  @override
  Future<String> duplicatePersonalTemplate(String templateId) =>
      throw UnimplementedError();

  @override
  Future<String> revisePersonalTemplate(
    String templateId,
    CreatePersonalWorkoutInput input,
  ) => throw UnimplementedError();

  @override
  Future<void> archivePersonalTemplate(String templateId) =>
      throw UnimplementedError();

  @override
  Future<WorkoutMutationDisposition> skipSet(String resultId) async =>
      WorkoutMutationDisposition.synced;

  @override
  Future<void> syncPendingMutations() async {}

  @override
  Future<String> startExecution(String templateId) async => 'execution-1';
}

class _ClockRepository extends _Repository {
  @override
  Future<WorkoutExecution?> getExecution(String executionId) async =>
      WorkoutExecution(
        id: 'execution-1',
        templateId: 'template-clock',
        templateName: 'Reloj',
        templateVersion: 1,
        status: WorkoutExecutionStatus.completed,
        startedAt: DateTime.utc(2026, 10, 20),
        observedTimerSeconds: 803,
        observedElapsedSeconds: 810,
        observedDistanceMeters: 2000,
        sets: [
          const WorkoutExecutionSet(
            id: 'set-clock',
            blockOrder: 0,
            blockName: 'Principal',
            itemOrder: 0,
            exerciseId: 'exercise-clock',
            exerciseName: 'Ejercicio',
            setOrder: 0,
            targetDurationSeconds: 90,
            actualDurationSeconds: 89,
            restAfterSeconds: 0,
            status: WorkoutSetStatus.completed,
          ),
        ],
      );
}

class _CorrectionRepository extends _Repository {
  _CorrectionRepository(this.duration);
  final bool duration;
  WorkoutSetCorrectionInput? lastCorrection;
  @override
  Future<WorkoutExecution?> getExecution(String executionId) async =>
      execution.copyWith(
        sets: [
          WorkoutExecutionSet(
            id: 'set-1',
            blockOrder: 0,
            blockName: 'Principal',
            itemOrder: 0,
            exerciseId: 'exercise-1',
            exerciseName: 'Ejercicio',
            setOrder: 0,
            targetReps: duration ? null : 10,
            targetDurationSeconds: duration ? 30 : null,
            targetRir: 3,
            actualReps: duration ? null : 8,
            actualDurationSeconds: duration ? 30 : null,
            actualRir: 2.5,
            restAfterSeconds: 0,
            status: WorkoutSetStatus.completed,
            completedAt: DateTime.now(),
          ),
        ],
      );
  @override
  Future<void> correctSet(WorkoutSetCorrectionInput correction) async =>
      lastCorrection = correction;
}

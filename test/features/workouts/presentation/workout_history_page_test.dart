import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
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

    expect(find.text('Objetivo · 10 rep'), findsOneWidget);
    expect(find.text('Realizado · 8 rep · RIR 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el detalle muestra el resultado agregado de un AMRAP', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _AmrapRepository();
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
    expect(find.text('Parcial · Flexiones: 3 rep'), findsOneWidget);
    expect(find.textContaining('Realizado ·'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _AmrapRepository extends _Repository {
  final amrapExecution = WorkoutExecution(
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
        partialReps: 3,
        completedAt: DateTime(2026, 9, 21, 17, 10),
      ),
    ],
  );

  @override
  Future<WorkoutExecution?> getExecution(String executionId) async =>
      amrapExecution;
}

class _Repository implements WorkoutRepository {
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
  Future<List<WorkoutExecution>> getExecutionHistory() async => [execution];

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

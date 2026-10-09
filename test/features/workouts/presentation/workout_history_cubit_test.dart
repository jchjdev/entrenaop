import 'dart:async';

import 'package:entrenaop/features/workouts/domain/entities/workout_history_query.dart';

import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/pending_workout_mutation.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el detalle descarta consultas anteriores y puede cerrarse durante una carga', () async {
    final repository = _FakeWorkoutRepository();
    final cubit = WorkoutHistoryDetailCubit(
      executionId: 'execution-1',
      getExecution: GetWorkoutExecutionUseCase(repository),
      correctSet: CorrectWorkoutSetUseCase(repository),
    );
    final first = Completer<WorkoutExecution?>();
    final second = Completer<WorkoutExecution?>();
    repository.nextExecution = () => first.future;
    final old = cubit.load();
    repository.nextExecution = () => second.future;
    final current = cubit.load();
    second.complete(_execution(status: WorkoutExecutionStatus.abandoned));
    await current;
    first.complete(_execution());
    await old;
    expect(cubit.state.execution?.status, WorkoutExecutionStatus.abandoned);
    final pending = Completer<WorkoutExecution?>();
    repository.nextExecution = () => pending.future;
    final closing = cubit.load();
    await cubit.close();
    pending.completeError(StateError('consulta cerrada'));
    await closing;
    await cubit.load();
  });
  test(
    'el refresco conserva resultados y admite reintento tras un fallo',
    () async {
      final repository = _FakeWorkoutRepository(history: [_execution()]);
      final cubit = WorkoutHistoryCubit(
        getHistory: GetWorkoutHistoryUseCase(repository),
      );
      addTearDown(cubit.close);
      await cubit.load();
      final pending = Completer<List<WorkoutExecution>>();
      repository.nextHistory = () => pending.future;
      final refresh = cubit.load();
      expect(cubit.state.status, WorkoutHistoryStatus.loaded);
      expect(cubit.state.isRefreshing, isTrue);
      expect(cubit.state.executions, hasLength(1));
      pending.completeError(StateError('sin conexión'));
      await refresh;
      expect(cubit.state.executions, hasLength(1));
      expect(cubit.state.isRefreshing, isFalse);
      expect(cubit.state.errorMessage, isNotNull);
      repository.nextHistory = null;
      await cubit.load();
      expect(cubit.state.errorMessage, isNull);
    },
  );

  test('una respuesta anterior no sustituye la última y cerrar durante carga es seguro', () async {
    final repository = _FakeWorkoutRepository();
    final cubit = WorkoutHistoryCubit(
      getHistory: GetWorkoutHistoryUseCase(repository),
    );
    final first = Completer<List<WorkoutExecution>>();
    final second = Completer<List<WorkoutExecution>>();
    repository.nextHistory = () => first.future;
    final oldLoad = cubit.load();
    repository.nextHistory = () => second.future;
    final newLoad = cubit.load();
    second.complete([_execution()]);
    await newLoad;
    first.completeError(StateError('respuesta antigua'));
    await oldLoad;
    expect(cubit.state.executions, hasLength(1));
    expect(cubit.state.errorMessage, isNull);
    final closing = Completer<List<WorkoutExecution>>();
    repository.nextHistory = () => closing.future;
    final lastLoad = cubit.load();
    await cubit.close();
    closing.complete([]);
    await lastLoad;
    await cubit.load();
  });

  test('carga las sesiones terminadas en el historial', () async {
    final execution = _execution();
    final repository = _FakeWorkoutRepository(history: [execution]);
    final cubit = WorkoutHistoryCubit(
      getHistory: GetWorkoutHistoryUseCase(repository),
    );

    await cubit.load();

    expect(cubit.state.status, WorkoutHistoryStatus.loaded);
    expect(cubit.state.executions, [execution]);
    await cubit.close();
  });

  test('el detalle rechaza una sesión que sigue activa', () async {
    final repository = _FakeWorkoutRepository(
      execution: _execution(status: WorkoutExecutionStatus.inProgress),
    );
    final cubit = WorkoutHistoryDetailCubit(
      executionId: 'execution-1',
      getExecution: GetWorkoutExecutionUseCase(repository),
      correctSet: CorrectWorkoutSetUseCase(repository),
    );

    await cubit.load();

    expect(cubit.state.status, WorkoutHistoryDetailStatus.failure);
    expect(
      cubit.state.errorMessage,
      'No encontramos esta sesión en tu historial.',
    );
    await cubit.close();
  });
}

WorkoutExecution _execution({
  WorkoutExecutionStatus status = WorkoutExecutionStatus.completed,
}) => WorkoutExecution(
  id: 'execution-1',
  templateId: 'template-1',
  templateName: 'Sesión inicial',
  templateVersion: 1,
  status: status,
  startedAt: DateTime.utc(2026, 9, 20, 17),
  completedAt: status == WorkoutExecutionStatus.inProgress
      ? null
      : DateTime.utc(2026, 9, 20, 17, 30),
  sets: const [],
);

class _FakeWorkoutRepository implements WorkoutRepository {
  @override
  Future<void> discardExecution(String executionId) async =>
      throw UnimplementedError();
  _FakeWorkoutRepository({this.history = const [], this.execution});

  final List<WorkoutExecution> history;
  final WorkoutExecution? execution;
  Future<List<WorkoutExecution>> Function()? nextHistory;
  Future<WorkoutExecution?> Function()? nextExecution;

  @override
  Future<List<WorkoutExecution>> getExecutionHistory({
    WorkoutHistoryQuery query = const WorkoutHistoryQuery(),
  }) async => nextHistory == null ? history : await nextHistory!();

  @override
  Future<WorkoutExecution?> getExecution(String executionId) async =>
      nextExecution == null ? execution : await nextExecution!();

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

import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  _FakeWorkoutRepository({this.history = const [], this.execution});

  final List<WorkoutExecution> history;
  final WorkoutExecution? execution;

  @override
  Future<List<WorkoutExecution>> getExecutionHistory() async => history;

  @override
  Future<WorkoutExecution?> getExecution(String executionId) async => execution;

  @override
  Future<void> abandonExecution(
    String executionId,
    WorkoutAbandonmentReason reason,
  ) async {}

  @override
  Future<void> completeSet(WorkoutSetResultInput result) async {}

  @override
  Future<void> correctSet(WorkoutSetCorrectionInput correction) async {}

  @override
  Future<void> finishExecution(
    String executionId, {
    required int finalRpe,
    String? notes,
  }) async {}

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async => null;

  @override
  Future<void> skipSet(String resultId) async {}

  @override
  Future<String> startExecution(String templateId) async => 'execution-1';
}

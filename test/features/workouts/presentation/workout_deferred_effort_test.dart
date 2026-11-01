import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/record_workout_effort.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_history_detail_page.dart';
import 'package:entrenaop/features/workouts/presentation/widgets/workout_effort_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutExecution completed({
  int? rpe,
  WorkoutResultSource source = WorkoutResultSource.device,
}) => WorkoutExecution(
  id: 'execution',
  templateId: 'template',
  templateName: 'Carrera',
  templateVersion: 1,
  status: WorkoutExecutionStatus.completed,
  startedAt: DateTime.utc(2026, 11, 1),
  sets: const [],
  finalRpe: rpe,
  resultSource: source,
);

class HistoryRepository extends Fake implements WorkoutRepository {
  WorkoutExecution value = completed();
  @override
  Future<WorkoutExecution?> getExecution(String executionId) async => value;
}

class Effort implements WorkoutEffortRepository {
  Effort(this.history);
  final HistoryRepository history;
  int calls = 0;
  @override
  Future<void> record(String executionId, int rpe) async {
    calls++;
    history.value = completed(rpe: rpe);
  }
}

void main() {
  testWidgets('el titular añade su esfuerzo desde el historial ya completado', (
    tester,
  ) async {
    final history = HistoryRepository();
    final effort = Effort(history);
    final cubit = WorkoutHistoryDetailCubit(
      executionId: 'execution',
      getExecution: GetWorkoutExecutionUseCase(history),
      correctSet: CorrectWorkoutSetUseCase(history),
      recordEffort: RecordWorkoutEffort(effort),
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
    expect(find.text('RPE final'), findsNothing);
    await tester.tap(find.text('Añadir esfuerzo'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(WorkoutEffortField));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('4/10'), findsOneWidget);
    expect(find.text('Añadir esfuerzo'), findsNothing);
    expect(effort.calls, 1);
    expect(cubit.state.execution!.status, WorkoutExecutionStatus.completed);
    expect(tester.takeException(), isNull);
  });

  test('Añadir RPE completa el dato pendiente y recarga el historial sin repetir el cierre', () async {
    final history = HistoryRepository();
    final effort = Effort(history);
    final cubit = WorkoutHistoryDetailCubit(
      executionId: 'execution',
      getExecution: GetWorkoutExecutionUseCase(history),
      correctSet: CorrectWorkoutSetUseCase(history),
      recordEffort: RecordWorkoutEffort(effort),
    );
    await cubit.load();
    expect(cubit.canRecordEffort, isTrue);
    await cubit.recordEffort(4);
    expect(cubit.state.execution!.finalRpe, 4);
    expect(cubit.state.execution!.status, WorkoutExecutionStatus.completed);
    expect(cubit.canRecordEffort, isFalse);
    await cubit.recordEffort(6);
    expect(effort.calls, 1);
    await cubit.close();
  });

  test('El cero y un valor fuera de escala no llegan al transporte', () {
    final effort = Effort(HistoryRepository());
    final record = RecordWorkoutEffort(effort);
    expect(() => record('execution', 0), throwsArgumentError);
    expect(() => record('execution', 11), throwsArgumentError);
    expect(effort.calls, 0);
  });
}

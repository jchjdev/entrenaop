import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
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
  Future<void> abandonExecution(
    String executionId,
    WorkoutAbandonmentReason reason,
  ) async {}

  @override
  Future<void> completeSet(WorkoutSetResultInput result) async {}

  @override
  Future<void> finishExecution(String executionId, int finalRpe) async {}

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async => null;

  @override
  Future<void> skipSet(String resultId) async {}

  @override
  Future<String> startExecution(String templateId) async => 'execution-1';
}

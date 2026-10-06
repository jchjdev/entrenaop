import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const goal = PreparationGoal(
    id: 'fas',
    program: PreparationProgram(
      id: PreparationProgramIds.fasPeriodicAssessment,
      name: 'Mejora FAS',
      kind: PreparationProgramKind.internalAssessment,
    ),
  );
  Future<void> mount(
    WidgetTester tester, {
    required Future<List<PreparationGoal>> Function() goals,
    List<WorkoutExecution> executions = const [],
  }) async {
    final cubit = WorkoutHistoryCubit(
      getHistory: GetWorkoutHistoryUseCase(_Repository(executions)),
    );
    await cubit.load();
    addTearDown(cubit.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: WorkoutHistoryPage(loadPreparations: goals),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'muestra marcas propias sin imponer Tropa y conserva su historial',
    (tester) async {
      await mount(tester, goals: () async => [goal]);
      expect(find.text('Marcas · Mejora FAS'), findsOneWidget);
      expect(find.text('Evaluación física · Tropa'), findsNothing);
      expect(find.text('Historial físico · Tropa'), findsNothing);
      await tester.ensureVisible(find.text('Otros historiales'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otros historiales'));
      await tester.pumpAndSettle();
      expect(find.text('Historial físico · Tropa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'la actividad cuenta fechas de cierre y no sesiones abandonadas',
    (tester) async {
      final now = DateTime.now();
      WorkoutExecution entry(
        String id,
        WorkoutExecutionStatus status,
        DateTime completed,
      ) => WorkoutExecution(
        id: id,
        templateId: 'template',
        templateName: 'Carrera',
        templateVersion: 1,
        status: status,
        startedAt: completed.subtract(const Duration(hours: 1)),
        completedAt: completed,
        sets: const [],
      );
      await mount(
        tester,
        goals: () async => [],
        executions: [
          entry('one', WorkoutExecutionStatus.completed, now),
          entry('two', WorkoutExecutionStatus.completed, now),
          entry(
            'three',
            WorkoutExecutionStatus.completed,
            now.subtract(const Duration(days: 1)),
          ),
          entry(
            'old',
            WorkoutExecutionStatus.completed,
            now.subtract(const Duration(days: 10)),
          ),
          entry('stopped', WorkoutExecutionStatus.abandoned, now),
        ],
      );
      expect(
        find.text('3 sesiones completadas · 2 días con entrenamiento'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'un fallo de preparaciones se puede reintentar sin ocultar el historial',
    (tester) async {
      var attempts = 0;
      await mount(
        tester,
        goals: () async {
          if (++attempts == 1) throw StateError('offline');
          return [goal];
        },
      );
      expect(find.text('Historial de entrenamientos'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Reintentar cargar tus preparaciones'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reintentar cargar tus preparaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Marcas · Mejora FAS'), findsOneWidget);
    },
  );
}

class _Repository implements WorkoutRepository {
  const _Repository(this.executions);
  final List<WorkoutExecution> executions;
  @override
  Future<List<WorkoutExecution>> getExecutionHistory() async => executions;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/manage_running_reference_selection_usecase.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_preparation_detail_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/running_intake_page.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('reinicia solo tras dos confirmaciones y actualiza el plan', (
    tester,
  ) async {
    const goal = PreparationGoal(
      id: 'fas-goal',
      program: PreparationProgram(
        id: PreparationProgramIds.fasPeriodicAssessment,
        name: 'Mejora FAS',
        kind: PreparationProgramKind.internalAssessment,
      ),
    );
    final cubit = PreparationDetailCubit(
      goalId: 'fas-goal',
      getDetail: GetPreparationDetailUseCase(
        goalRepository: const _Goals(goal),
        loadRunningTests: (_) async => const [],
        loadTroopAssessments: (_) async => const [],
        loadRunningReferenceCandidates: (_) async => const [],
        scheduleRepository: _Schedule(),
      ),
      now: () => DateTime(2026, 9, 30),
    );
    await cubit.load();
    var weeks = 1;
    var resetCalls = 0;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BlocProvider.value(
            value: cubit,
            child: RunningIntakePage(
              loadContext: ({required goalId, required programId}) async =>
                  null,
              loadSelectionState: (_) async =>
                  const RunningReferenceSelectionState(
                    selection: null,
                    candidate: null,
                    issues: [],
                  ),
              chooseReference: ({
                required goalId,
                required candidate,
                required confirmContinuity,
              }) async {},
              clearReference: (_) async {},
              loadScheduledWorkouts: (start, end) async => const [],
              loadPublishedWeeks: (_) async => weeks,
              resetPlan: (_) async {
                resetCalls++;
                weeks = 0;
                return {'decisions': 1, 'sessions': 2, 'executions': 2};
              },
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final button = find.text('Reiniciar planificación');
    await tester.scrollUntilVisible(button, 200);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(resetCalls, 0);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Reiniciar plan'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField).last, 'REINICIAR');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reiniciar plan'));
    await tester.pumpAndSettle();
    expect(resetCalls, 1);
    expect(
      find.text('Plan reiniciado. Ya puedes pautar de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Reiniciar planificación'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final dataOnly in [false, true]) {
    testWidgets('FAS muestra su marca y contexto; solo datos: $dataOnly', (
      tester,
    ) async {
      const goal = PreparationGoal(
        id: 'fas-goal',
        program: PreparationProgram(
          id: PreparationProgramIds.fasPeriodicAssessment,
          name: 'Mejora FAS',
          kind: PreparationProgramKind.internalAssessment,
        ),
      );
      final cubit = PreparationDetailCubit(
        goalId: 'fas-goal',
        getDetail: GetPreparationDetailUseCase(
          goalRepository: const _Goals(goal),
          loadRunningTests: (_) async => const [],
          loadTroopAssessments: (_) async => const [],
          loadRunningReferenceCandidates: (_) async => [
            RunningReferenceCandidate(
              goalId: 'fas-goal',
              programId: PreparationProgramIds.fasPeriodicAssessment,
              recordId: 'fas-attempt',
              testId: 'run_2000_m',
              completedAt: DateTime(2026, 9, 28),
              durationSeconds: 650,
              protocolVersion: null,
              source: RunningReferenceSource.fasPeriodicAssessment,
              scoringVersion: 'fas-v1',
            ),
          ],
          scheduleRepository: _Schedule(),
        ),
        now: () => DateTime(2026, 9, 30),
      );
      await cubit.load();
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            home: RunningIntakePage(
              dataOnly: dataOnly,
              loadContext: ({required goalId, required programId}) async =>
                  null,
              loadSelectionState: (_) async =>
                  const RunningReferenceSelectionState(
                    selection: null,
                    candidate: null,
                    issues: [],
                  ),
              chooseReference: ({
                required goalId,
                required candidate,
                required confirmContinuity,
              }) async {},
              clearReference: (_) async {},
              loadScheduledWorkouts: (start, end) async => const [],
              now: () => DateTime(2026, 9, 30),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          dataOnly ? 'Datos de carrera' : 'Plan y preferencias de carrera',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('2 km · 10:50'), findsOneWidget);
      expect(find.text('Evaluación periódica FAS'), findsOneWidget);
      expect(find.text('Dentro de 30 días'), findsOneWidget);
      expect(find.text('Completar contexto'), findsOneWidget);
      expect(find.text('Registrar un control de 2 km'), findsOneWidget);
      expect(find.text('Ver las marcas de esta preparación'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -1800));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'La planificación automática de carrera aún no está conectada',
        ),
        dataOnly ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('Continuar con el programa'),
        dataOnly ? findsOneWidget : findsNothing,
      );
      if (dataOnly) {
        final action = find.widgetWithText(
          FilledButton,
          'Continuar con el programa',
        );
        expect(action, findsOneWidget);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    });
  }
}

class _Goals implements PreparationGoalRepository {
  const _Goals(this.goal);
  final PreparationGoal goal;

  @override
  Future<List<PreparationGoal>> getActiveGoals() async => [goal];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Schedule implements WorkoutScheduleRepository {
  @override
  Future<List<ScheduledWorkout>> getRange(DateTime start, DateTime end) async =>
      [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

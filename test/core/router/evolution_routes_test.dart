import 'dart:async';

import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_progress_calculator.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/get_physical_assessment_history_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_cubit.dart';
import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_history_page.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/program_assessment/data/program_assessment_repository.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_history_query.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/evolution_fixtures.dart';

void main() {
  late _Auth auth;
  late _Goals goals;
  late _Marks marks;
  final cubits = <WorkoutHistoryCubit>[];
  final sources = <_Sessions>[];
  setUp(() {
    cubits.clear();
    sources.clear();
    auth = _Auth();
    goals = _Goals(auth);
    marks = _Marks(auth);
    sl.registerSingleton<PreparationGoalRepository>(goals);
    sl.registerSingleton<ProgramAssessmentRepository>(marks);
    sl.registerFactoryParam<WorkoutHistoryDetailCubit, String, void>((id, _) {
      final repository = _Sessions(auth.userId);
      return WorkoutHistoryDetailCubit(
        executionId: id,
        getExecution: GetWorkoutExecutionUseCase(repository),
        correctSet: CorrectWorkoutSetUseCase(repository),
      )..load();
    });
    sl.registerFactory<PhysicalAssessmentHistoryCubit>(
      () => PhysicalAssessmentHistoryCubit(
        getHistory: GetPhysicalAssessmentHistoryUseCase(_Physical(auth.userId)),
        progressCalculator: const AssessmentProgressCalculator(),
      )..load(),
    );
    sl.registerSingleton<FasPeriodicAssessmentRepository>(_Fas(auth));
    sl.registerFactory<WorkoutHistoryCubit>(() {
      final source = _Sessions(auth.userId);
      sources.add(source);
      final cubit = WorkoutHistoryCubit(
        getHistory: GetWorkoutHistoryUseCase(source),
      )..load();
      cubits.add(cubit);
      return cubit;
    });
  });
  tearDown(() async {
    await sl.reset();
    await auth.close();
  });

  Future<AppRouter> mount(
    WidgetTester t, {
    String? path,
    bool settle = true,
  }) async {
    final router = AppRouter(auth);
    addTearDown(router.dispose);
    router.config.go(path ?? '/assessment/history');
    await t.pumpWidget(
      MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router.config),
    );
    if (settle) {
      await t.pumpAndSettle();
    }
    return router;
  }

  testWidgets(
    'Marcas abre resultados, mantiene filtros y vuelve a consultar al retornar',
    (t) async {
      final router = await mount(t);
      final cubit = cubits.single;
      await cubit.filter(
        const WorkoutHistoryQuery(
          preparationGoalId: 'generic',
          status: WorkoutExecutionStatus.completed,
        ),
      );
      await t.pumpAndSettle();
      final calls = sources.single.calls;
      await t.ensureVisible(find.text('Marcas · Preparación A'));
      await t.tap(find.text('Marcas · Preparación A'));
      await t.pumpAndSettle();
      expect(
        router.config.routeInformationProvider.value.uri.path,
        '/assessment/history/preparations/generic',
      );
      expect(find.text('Marcas y resultados'), findsOneWidget);
      expect(
        find.text('Todavía no hay marcas guardadas en esta preparación.'),
        findsOneWidget,
      );
      expect(marks.requests, ['A:generic']);
      router.config.pop();
      await t.pumpAndSettle();
      expect(cubits, hasLength(1));
      expect(cubits.single, same(cubit));
      expect(cubit.state.query.preparationGoalId, 'generic');
      expect(cubit.state.query.status, WorkoutExecutionStatus.completed);
      expect(sources.single.calls, calls + 1);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'renovar sesión conserva consulta; cambiar cuenta descarta resultados tardíos',
    (t) async {
      await mount(t);
      await cubits.single.filter(
        const WorkoutHistoryQuery(status: WorkoutExecutionStatus.abandoned),
      );
      final old = cubits.single;
      auth.loading();
      await t.pump();
      auth.setUser('A', renewed: true);
      await t.pumpAndSettle();
      expect(cubits, hasLength(1));
      expect(old.state.query.status, WorkoutExecutionStatus.abandoned);
      final pending = Completer<List<WorkoutExecution>>();
      sources.first.pending = pending.future;
      final oldLoad = old.load();
      await t.pump();
      auth.setUser('B');
      await t.pumpAndSettle();
      expect(old.isClosed, isTrue);
      expect(cubits, hasLength(2));
      expect(cubits.last.state.query.hasFilters, isFalse);
      expect(find.text('Sesión A'), findsNothing);
      expect(find.text('Sesión B'), findsOneWidget);
      pending.complete(sources.first.rows);
      await oldLoad;
      await t.pumpAndSettle();
      expect(find.text('Sesión B'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Marcas también renueva su página por cuenta y evita datos antiguos',
    (t) async {
      await mount(t, path: '/assessment/history/preparations/generic');
      expect(find.text('Preparación A'), findsOneWidget);
      auth.loading();
      await t.pump();
      auth.setUser('A', renewed: true);
      await t.pumpAndSettle();
      expect(marks.requests, ['A:generic']);
      auth.setUser('B');
      await t.pumpAndSettle();
      expect(find.text('Preparación B'), findsOneWidget);
      expect(find.text('Preparación A'), findsNothing);
      expect(marks.requests, ['A:generic', 'B:generic']);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('el detalle de sesión se renueva por cuenta y por ejecución', (
    t,
  ) async {
    final router = await mount(t, path: '/assessment/history/workouts/A');
    final old = t
        .element(find.text('Sesión A'))
        .read<WorkoutHistoryDetailCubit>();
    auth.setUser('B');
    await t.pumpAndSettle();
    expect(old.isClosed, isTrue);
    expect(find.text('Sesión A'), findsNothing);
    expect(find.text('Sesión B'), findsOneWidget);
    final current = t
        .element(find.text('Sesión B'))
        .read<WorkoutHistoryDetailCubit>();
    router.config.go('/assessment/history/workouts/other');
    await t.pumpAndSettle();
    expect(current.isClosed, isTrue);
    expect(
      t
          .element(find.text('Sesión B'))
          .read<WorkoutHistoryDetailCubit>()
          .executionId,
      'other',
    );
    expect(t.takeException(), isNull);
  });
  testWidgets('el historial físico renueva su controlador al cambiar cuenta', (
    t,
  ) async {
    await mount(t, path: '/assessment/history/physical');
    final old = t
        .element(find.text('Evaluación física · Tropa'))
        .read<PhysicalAssessmentHistoryCubit>();
    auth.setUser('B');
    await t.pumpAndSettle();
    expect(old.isClosed, isTrue);
    final current = t
        .element(find.text('Evaluación física · Tropa'))
        .read<PhysicalAssessmentHistoryCubit>();
    expect(current, isNot(same(old)));
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'el historial personal FAS vuelve a consultar al cambiar cuenta',
    (t) async {
      await t.runAsync(
        evolutionFasData,
      ); // Precarga la cadena del asset para el runner.
      await mount(t, path: '/assessment/fas-history', settle: false);
      await t.runAsync(evolutionFasData);
      await t.pumpAndSettle();
      final repo = sl<FasPeriodicAssessmentRepository>() as _Fas;
      final first = t
          .widget<FasPeriodicHistoryPage>(find.byType(FasPeriodicHistoryPage))
          .key;
      auth.setUser('B');
      await t.pump();
      await t.runAsync(evolutionFasData);
      await t.pump();
      expect(repo.requests, ['A', 'B']);
      expect(
        t
            .widget<FasPeriodicHistoryPage>(find.byType(FasPeriodicHistoryPage))
            .key,
        isNot(first),
      );
      expect(t.takeException(), isNull);
    },
  );
}

class _Auth extends Cubit<AuthState> implements AuthCubit {
  _Auth() : super(_state('A'));
  String userId = 'A';
  void loading() => emit(AuthLoading());
  void setUser(String id, {bool renewed = false}) {
    userId = id;
    emit(_state(id, renewed: renewed));
  }

  static AuthAuthenticated _state(String id, {bool renewed = false}) =>
      AuthAuthenticated(
        user: UserEntity(
          id: id,
          email: '${renewed ? 'renewed' : id}@example.test',
          role: 'free',
          createdAt: DateTime(2026),
        ),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Goals implements PreparationGoalRepository {
  _Goals(this.auth);
  final _Auth auth;
  @override
  Future<List<PreparationGoal>> getActiveGoals() async => [
    PreparationGoal(
      id: 'generic',
      program: PreparationProgram(
        id: 'fixture',
        name: 'Preparación ${auth.userId}',
        kind: PreparationProgramKind.internalAssessment,
      ),
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Marks implements ProgramAssessmentRepository {
  _Marks(this.auth);
  final _Auth auth;
  final requests = <String>[];
  @override
  Future<List<ProgramAssessmentAttempt>> history(String id) async {
    requests.add('${auth.userId}:$id');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sessions implements WorkoutRepository {
  _Sessions(this.user);
  final String user;
  int calls = 0;
  Future<List<WorkoutExecution>>? pending;
  List<WorkoutExecution> get rows => [
    WorkoutExecution(
      id: user,
      templateId: 'template',
      templateName: 'Sesión $user',
      templateVersion: 1,
      startedAt: DateTime(2026, 10, 6),
      completedAt: DateTime(2026, 10, 6, 10),
      status: WorkoutExecutionStatus.completed,
      sets: const [],
    ),
  ];
  @override
  Future<List<WorkoutExecution>> getExecutionHistory({
    WorkoutHistoryQuery query = const WorkoutHistoryQuery(),
  }) async {
    calls++;
    return pending ?? rows;
  }

  @override
  Future<WorkoutExecution?> getExecution(String id) async => rows.single;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Physical implements PhysicalAssessmentRepository {
  _Physical(this.user);
  final String user;
  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistory() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Fas implements FasPeriodicAssessmentRepository {
  _Fas(this.auth);
  final _Auth auth;
  final requests = <String>[];
  @override
  Future<List<FasPeriodicAssessmentEntry>> history({String? goalId}) async {
    requests.add(auth.userId);
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

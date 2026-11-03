import 'dart:async';

import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_detail.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/published_adaptive_week_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_preparation_detail_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/adaptive_plan_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/adaptive_plan_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_detail_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_goal_page.dart';
import 'package:entrenaop/features/pro/domain/pro_access.dart';
import 'package:entrenaop/features/pro/presentation/widgets/pro_access_widgets.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_hub_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pro_access_fixture.dart';

final _week = DateTime(2026, 11, 2);
PreparationGoal _goal(String owner) => PreparationGoal(
  id: 'g',
  program: PreparationProgram(
    id: 'program',
    name: 'Preparación $owner',
    kind: PreparationProgramKind.internalAssessment,
  ),
);
PreparationTrainingData _data(String owner) => PreparationTrainingData(
  programName: 'Preparación $owner',
  programState: const {'status': 'paused'},
  catalog: const [],
  context: null,
  runningContext: null,
  references: const [],
  objectives: const [],
  relations: const [],
  publishedWeeks: [_week, _week.subtract(const Duration(days: 7))],
);

void main() {
  tearDown(sl.reset);

  Future<
    ({
      AppRouter router,
      _Auth auth,
      _Training training,
      _Detail detail,
      List<DashboardCubit> dashboards,
    })
  >
  mount(WidgetTester tester, String location) async {
    final auth = _Auth();
    addTearDown(auth.close);
    String owner() => (auth.state as AuthAuthenticated).user.id;
    final training = _Training(owner);
    final detail = _Detail(owner);
    final goals = _Goals(owner);
    final dashboards = <DashboardCubit>[];
    sl.registerSingleton<ProAccessRepository>(ProAccessFixture());
    sl.registerSingleton<PreparationTrainingRepository>(training);
    sl.registerSingleton<GetPreparationDetailUseCase>(detail);
    sl.registerSingleton<PublishedAdaptiveWeekRepository>(_Published(owner));
    sl.registerSingleton<PreparationGoalRepository>(goals);
    sl.registerFactory<PreparationGoalCubit>(
      () => PreparationGoalCubit(repository: goals)..load(),
    );
    sl.registerFactoryParam<PreparationDetailCubit, String, DateTime?>(
      (id, week) => PreparationDetailCubit(
        goalId: id,
        getDetail: detail,
        initialWeek: week,
      )..load(),
    );
    sl.registerFactory<DashboardCubit>(() {
      final cubit = DashboardCubit(getOverview: _Overview(owner()))..load();
      dashboards.add(cubit);
      return cubit;
    });
    final router = AppRouter(auth);
    addTearDown(router.dispose);
    router.config.go(location);
    await tester.pumpWidget(
      MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router.config),
    );
    await tester.pumpAndSettle();
    return (
      router: router,
      auth: auth,
      training: training,
      detail: detail,
      dashboards: dashboards,
    );
  }

  testWidgets(
    'la ficha recrea su estado al cambiar cuenta y descarta la respuesta anterior',
    (tester) async {
      final result = await mount(tester, '/plan/goal/g?week=2026-10-26');
      final original = tester
          .element(find.byType(PreparationDetailPage))
          .read<PreparationDetailCubit>();
      result.auth.setUser('A', email: 'renewed@example.test');
      await tester.pumpAndSettle();
      expect(
        tester
            .element(find.byType(PreparationDetailPage))
            .read<PreparationDetailCubit>(),
        same(original),
      );
      expect(original.state.weekStart, DateTime(2026, 10, 26));
      final slow = Completer<PreparationDetail>();
      result.detail.next = slow.future;
      final oldLoad = original.load();
      await tester.pump();
      result.auth.setUser('B');
      await tester.pumpAndSettle();
      final current = tester
          .element(find.byType(PreparationDetailPage))
          .read<PreparationDetailCubit>();
      expect(current, isNot(same(original)));
      expect(original.isClosed, isTrue);
      expect(find.text('Preparación A'), findsNothing);
      expect(find.text('Preparación B'), findsOneWidget);
      slow.complete(
        PreparationDetail(
          goal: _goal('A'),
          weekStart: _week,
          weekEnd: _week.add(const Duration(days: 6)),
          weeklyWorkouts: const [],
        ),
      );
      await oldLoad;
      await tester.pumpAndSettle();
      expect(find.text('Preparación B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'el catálogo conserva renovación y recrea datos al cambiar cuenta',
    (tester) async {
      final result = await mount(tester, '/plan/goal');
      final original = tester
          .element(find.byType(PreparationGoalPage))
          .read<PreparationGoalCubit>();
      expect(original.state.goals.single.program.name, 'Preparación A');
      result.auth.setUser('A', email: 'renewed@example.test');
      await tester.pumpAndSettle();
      expect(
        tester
            .element(find.byType(PreparationGoalPage))
            .read<PreparationGoalCubit>(),
        same(original),
      );
      result.auth.setUser('B');
      await tester.pumpAndSettle();
      final current = tester
          .element(find.byType(PreparationGoalPage))
          .read<PreparationGoalCubit>();
      expect(current, isNot(same(original)));
      expect(original.isClosed, isTrue);
      expect(current.state.goals.single.program.name, 'Preparación B');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ficha y plan reutilizan contexto sin acumular ciclos y conservan semana',
    (tester) async {
      final result = await mount(tester, '/plan/goal/g/plan?week=2026-10-26');
      for (var i = 0; i < 3; i++) {
        await tester.ensureVisible(find.text('Ver preparación y marcas'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver preparación y marcas'));
        await tester.pumpAndSettle();
        expect(result.router.config.state.uri.path, '/plan/goal/g');
        expect(
          result.router.config.state.uri.queryParameters['week'],
          '2026-10-26',
        );
        final detail = tester
            .element(find.byType(PreparationDetailPage))
            .read<PreparationDetailCubit>();
        expect(detail.state.weekStart, DateTime(2026, 10, 26));
        await tester.ensureVisible(find.text('Ver mi plan'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver mi plan'));
        await tester.pumpAndSettle();
        expect(result.router.config.state.uri.path, '/plan/goal/g/plan');
      }
      await tester.ensureVisible(find.text('Ver preparación y marcas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver preparación y marcas'));
      await tester.pumpAndSettle();
      result.router.config.pop();
      await tester.pumpAndSettle();
      expect(result.router.config.state.uri.path, '/plan/goal');
      expect(tester.takeException(), isNull);
    },
  );

  for (final origin in ['/plan', '/plan/preparations']) {
    testWidgets(
      'plan y ficha conservan origen $origin sin añadir una segunda ficha',
      (tester) async {
        final result = await mount(tester, origin);
        result.router.config.push('/plan/goal/g/plan?week=2026-10-26');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Ver preparación y marcas'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ver preparación y marcas'));
        await tester.pumpAndSettle();
        expect(result.router.config.state.uri.path, '/plan/goal/g');
        result.router.config.pop();
        await tester.pumpAndSettle();
        expect(result.router.config.state.uri.path, origin);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('volver a ficha conserva la semana elegida dentro del plan', (
    tester,
  ) async {
    final result = await mount(tester, '/plan/goal/g/plan?week=2026-10-26');
    final plan = tester
        .element(find.byType(AdaptivePlanPage))
        .read<AdaptivePlanCubit>();
    await plan.load(week: _week);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver preparación y marcas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver preparación y marcas'));
    await tester.pumpAndSettle();
    expect(
      result.router.config.state.uri.queryParameters['week'],
      '2026-11-02',
    );
    expect(
      tester
          .element(find.byType(PreparationDetailPage))
          .read<PreparationDetailCubit>()
          .state
          .weekStart,
      _week,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'volver desde plan reutiliza la ficha abierta desde gestión y su semana',
    (tester) async {
      final result = await mount(tester, '/plan/preparations');
      result.router.config.push('/plan/goal/g?week=2026-10-26');
      await tester.pumpAndSettle();
      final original = tester
          .element(find.byType(PreparationDetailPage))
          .read<PreparationDetailCubit>();
      await tester.ensureVisible(find.text('Ver mi plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver mi plan'));
      await tester.pumpAndSettle();
      await tester
          .element(find.byType(AdaptivePlanPage))
          .read<AdaptivePlanCubit>()
          .load(week: _week);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ver preparación y marcas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver preparación y marcas'));
      await tester.pumpAndSettle();
      final restored = tester
          .element(find.byType(PreparationDetailPage))
          .read<PreparationDetailCubit>();
      expect(restored, same(original));
      expect(restored.state.weekStart, _week);
      result.router.config.pop();
      await tester.pumpAndSettle();
      expect(result.router.config.state.uri.path, '/plan/preparations');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Free consulta directamente el plan real sin gate Pro ni cargar Entrenar',
    (tester) async {
      final result = await mount(tester, '/plan/goal/g/plan?week=2026-10-26');
      expect(find.byType(AdaptivePlanPage), findsOneWidget);
      expect(find.byType(ProAccessGate), findsNothing);
      expect(find.text('Pauta conservada A'), findsOneWidget);
      expect(find.textContaining('Comenzar'), findsNothing);
      expect(result.training.reads, ['A:g']);
      expect(result.dashboards, isEmpty);
      final original = tester
          .element(find.byType(AdaptivePlanPage))
          .read<AdaptivePlanCubit>();
      expect(original.state.week, DateTime(2026, 10, 26));

      result.auth.setUser('A', email: 'renewed@example.test');
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byType(AdaptivePlanPage)).read<AdaptivePlanCubit>(),
        same(original),
      );
      expect(original.state.week, DateTime(2026, 10, 26));
      expect(result.training.reads, ['A:g']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'el router real recrea el plan al cambiar cuenta y descarta respuesta tardía',
    (tester) async {
      final result = await mount(tester, '/plan/goal/g/plan');
      final original = tester
          .element(find.byType(AdaptivePlanPage))
          .read<AdaptivePlanCubit>();
      final slow = Completer<PreparationTrainingData>();
      result.training.next = slow.future;
      final oldLoad = original.load();
      await tester.pump();
      result.auth.setUser('B');
      await tester.pumpAndSettle();
      final current = tester
          .element(find.byType(AdaptivePlanPage))
          .read<AdaptivePlanCubit>();
      expect(current, isNot(same(original)));
      expect(original.isClosed, isTrue);
      expect(find.text('Pauta conservada A'), findsNothing);
      expect(find.text('Pauta conservada B'), findsOneWidget);
      slow.complete(_data('A'));
      await oldLoad;
      await tester.pumpAndSettle();
      expect(find.text('Pauta conservada B'), findsOneWidget);
      expect(result.dashboards, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gestión directa carga sólo su resumen y conserva identidad al renovar',
    (tester) async {
      final result = await mount(tester, '/plan/preparations');
      expect(find.byType(TrainingPreparationsPage), findsOneWidget);
      expect(find.text('Preparación A'), findsOneWidget);
      expect(result.dashboards, hasLength(1));
      expect(result.training.reads, isEmpty);
      final original = result.dashboards.single;
      result.auth.setUser('A', email: 'renewed@example.test');
      await tester.pumpAndSettle();
      expect(result.dashboards, hasLength(1));
      expect(original.isClosed, isFalse);
      result.auth.setUser('B');
      await tester.pumpAndSettle();
      expect(result.dashboards, hasLength(2));
      expect(original.isClosed, isTrue);
      expect(find.text('Preparación A'), findsNothing);
      expect(find.text('Preparación B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Auth extends Cubit<AuthState> implements AuthCubit {
  _Auth() : super(_state('A'));
  void setUser(String id, {String? email}) => emit(_state(id, email: email));
  static AuthAuthenticated _state(String id, {String? email}) =>
      AuthAuthenticated(
        user: UserEntity(
          id: id,
          email: email ?? '$id@example.test',
          role: 'free',
          createdAt: DateTime(2026),
        ),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Training implements PreparationTrainingRepository {
  _Training(this.owner);
  final String Function() owner;
  final reads = <String>[];
  Future<PreparationTrainingData>? next;
  @override
  Future<PreparationTrainingData> load(String goalId) async {
    final user = owner();
    reads.add('$user:$goalId');
    final pending = next;
    next = null;
    return pending == null ? _data(user) : await pending;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'No se permite escribir al consultar: ${invocation.memberName}',
  );
}

class _Detail implements GetPreparationDetailUseCase {
  _Detail(this.owner);
  final String Function() owner;
  Future<PreparationDetail>? next;
  @override
  Future<PreparationDetail> call(
    String goal,
    DateTime start,
    DateTime end,
  ) async {
    final pending = next;
    next = null;
    return pending == null
        ? PreparationDetail(
            goal: _goal(owner()),
            weekStart: start,
            weekEnd: end,
            weeklyWorkouts: const [],
          )
        : await pending;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Published implements PublishedAdaptiveWeekRepository {
  _Published(this.owner);
  final String Function() owner;
  @override
  Future<PublishedAdaptiveWeek> read(String goal, DateTime week) async =>
      PublishedAdaptiveWeek(
        preparationDecision: {
          'sessions': [
            {
              'date': week.toIso8601String().split('T').first,
              'kind': 'performance',
              'name': 'Pauta conservada ${owner()}',
              'minutes': 30,
            },
          ],
        },
      );
}

class _Overview implements GetPreparationOverviewUseCase {
  _Overview(this.owner);
  final String owner;
  @override
  Future<PreparationOverview> call() async => PreparationOverview(
    assessments: const [],
    preferences: null,
    goals: [_goal(owner)],
    weekStart: _week,
    weeklyWorkouts: const [],
  );
}

class _Goals implements PreparationGoalRepository {
  _Goals(this.owner);
  final String Function() owner;
  @override
  Future<List<PreparationGoal>> getActiveGoals() async => [_goal(owner())];
  @override
  Future<List<PreparationProgram>> getAvailablePrograms() async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Operación inesperada: ${invocation.memberName}');
}

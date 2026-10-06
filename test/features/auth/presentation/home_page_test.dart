import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/presentation/pages/home_page.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/repositories/home_favorites_repository.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/dashboard/presentation/home_day_selection.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final today = DateUtils.dateOnly(DateTime.now());
  final week = today.subtract(Duration(days: today.weekday - 1));
  const goal = PreparationGoal(
    id: 'goal-1',
    program: PreparationProgram(
      id: PreparationProgramIds.fasPeriodicAssessment,
      name: 'Mejora FAS',
      kind: PreparationProgramKind.internalAssessment,
    ),
  );
  PreparationOverview overview({
    bool newUser = false,
    List<ScheduledWorkout> workouts = const [],
    bool needsReview = false,
  }) => PreparationOverview(
    assessments: const [],
    preferences: null,
    goals: newUser ? const [] : const [goal],
    weekStart: week,
    weeklyWorkouts: workouts,
    programs: newUser
        ? const []
        : [
            AdaptiveProgramProgress(
              goalId: 'goal-1',
              name: 'Mejora FAS',
              status: needsReview ? 'needs_review' : 'training',
              message: 'Revisa tu contexto actual.',
            ),
          ],
  );
  ScheduledWorkout workout(ScheduledWorkoutStatus status) => ScheduledWorkout(
    id: 'scheduled-1',
    templateId: 'template-1',
    templateName: 'Carrera de hoy',
    templateVersion: 1,
    scheduledDate: today,
    source: ScheduledWorkoutSource.algorithm,
    status: status,
    preparationGoalId: 'goal-1',
    executionId: status == ScheduledWorkoutStatus.planned
        ? null
        : 'execution-1',
  );

  Future<GoRouter> mount(
    WidgetTester tester,
    PreparationOverview data, {
    double width = 360,
    double textScale = 1,
    _Favorites? favorites,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = DashboardCubit(getOverview: _Overview(data));
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: HomePage(
              favoritesRepository: favorites ?? _Favorites(),
              userId: 'user-1',
            ),
          ),
        ),
        GoRoute(
          path: '/plan/week',
          builder: (_, state) => Scaffold(
            body: Text(
              'Agenda ${state.uri.queryParameters['date']} · ${state.uri.queryParameters['session']}',
            ),
          ),
        ),
        GoRoute(
          path: '/plan/week/active/:id',
          builder: (_, _) => const Scaffold(body: Text('Retomada')),
        ),
        GoRoute(
          path: '/assessment/history/workouts/:id',
          builder: (_, _) => const Scaffold(body: Text('Resultado')),
        ),
        GoRoute(
          path: '/plan/goal/:id/training',
          builder: (_, _) => const Scaffold(body: Text('Revisión')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: EntrenaTheme.dark,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  for (final width in [320.0, 1100.0]) {
    testWidgets(
      'primer acceso conserva calendario y siguiente paso a $width px',
      (tester) async {
        await mount(tester, overview(newUser: true), width: width);
        expect(
          find.text('Define qué pruebas estás preparando'),
          findsOneWidget,
        );
        expect(find.text('Sesión inicial de EntrenaOP'), findsNothing);
        expect(
          tester.getTopLeft(find.text('Ver semana')).dy,
          lessThan(
            tester
                .getTopLeft(find.text('Define qué pruebas estás preparando'))
                .dy,
          ),
        );
        await tester.scrollUntilVisible(
          find.text('Tus favoritos'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('PAEF / PAFAS'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('la sesión diaria abre su agenda sin iniciar una ejecución', (
    tester,
  ) async {
    await mount(
      tester,
      overview(workouts: [workout(ScheduledWorkoutStatus.planned)]),
    );
    expect(find.text('Carrera de hoy'), findsOneWidget);
    await tester.tap(find.text('Ver sesión'));
    await tester.pumpAndSettle();
    expect(
      find.text('Agenda ${homeDateParam(today)} · scheduled-1'),
      findsOneWidget,
    );
  });
  testWidgets('al seleccionar otro día no inventa un descanso', (tester) async {
    await mount(
      tester,
      overview(workouts: [workout(ScheduledWorkoutStatus.planned)]),
    );
    final otherDay = week.add(Duration(days: today.weekday == 1 ? 1 : 0));
    await tester.tap(
      find.byKey(ValueKey('home-day-${homeDateParam(otherDay)}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('No tienes sesión programada'), findsOneWidget);
    expect(find.textContaining('descanso'), findsNothing);
    expect(find.text('Carrera de hoy'), findsNothing);
  });
  testWidgets('retoma y consulta resultados existentes', (tester) async {
    await mount(
      tester,
      overview(workouts: [workout(ScheduledWorkoutStatus.inProgress)]),
    );
    await tester.tap(find.text('Retomar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Retomada'), findsOneWidget);
  });
  testWidgets('una sesión completada lleva al resultado', (tester) async {
    await mount(
      tester,
      overview(workouts: [workout(ScheduledWorkoutStatus.completed)]),
    );
    await tester.tap(find.text('Ver resultado'));
    await tester.pumpAndSettle();
    expect(find.text('Resultado'), findsOneWidget);
  });
  testWidgets('una revisión pendiente se conserva como siguiente paso', (
    tester,
  ) async {
    await mount(tester, overview(needsReview: true));
    expect(find.text('Tu programa necesita un dato'), findsOneWidget);
    await tester.tap(find.text('Revisar lo pendiente'));
    await tester.pumpAndSettle();
    expect(find.text('Revisión'), findsOneWidget);
  });
  testWidgets('Inicio admite texto ampliado sin desbordar', (tester) async {
    await mount(tester, overview(newUser: true), width: 320, textScale: 2);
    await tester.scrollUntilVisible(
      find.text('Tus favoritos'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}

class _Overview implements GetPreparationOverviewUseCase {
  const _Overview(this.overview);
  final PreparationOverview overview;
  @override
  Future<PreparationOverview> call() async => overview;
}

class _Favorites implements HomeFavoritesRepository {
  List<HomeShortcut> items = List.of(defaultHomeFavorites);
  @override
  Future<List<HomeShortcut>> load(String userId) async => List.of(items);
  @override
  Future<void> save(String userId, List<HomeShortcut> favorites) async {
    items = List.of(favorites);
  }
}

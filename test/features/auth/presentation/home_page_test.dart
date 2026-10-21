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
import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';
import 'package:workout_core/guided_program.dart';
import 'package:entrena_ui/entrena_ui.dart' show EntrenaProgramCard;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/guided_program_fixture.dart';
import '../../../helpers/performance_visual_review.dart';

import 'package:entrenaop/features/library/presentation/library_hub_page.dart';

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
    _Overview? source,
    GuidedProgramRepository? guided,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = DashboardCubit(getOverview: source ?? _Overview(data));
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: HomePage(
              favoritesRepository: favorites ?? _Favorites(),
              userId: 'user-1',
              guidedPrograms: guided,
            ),
          ),
        ),
        GoRoute(
          path: '/library',
          builder: (_, state) => LibraryHubPage(
            guided: guided,
            initialTab: state.uri.queryParameters['tab'] ?? 'sessions',
          ),
        ),
        GoRoute(
          path: '/library/programs/:id',
          builder: (_, _) => const Scaffold(body: Text('Ficha del programa')),
        ),
        GoRoute(
          path: '/plan',
          builder: (_, _) => const Scaffold(body: Text('Elegir preparación')),
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
          path: '/plan/goal/:id',
          builder: (_, _) => const Scaffold(body: Text('Preparación elegida')),
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

  testWidgets(
    'la sesión del preparador no queda oculta por la revisión del plan automático',
    (tester) async {
      final coach = ScheduledWorkout(
        id: 'coach',
        templateId: 'private',
        templateName: 'Sesión de mi preparador',
        templateVersion: 1,
        scheduledDate: today,
        source: ScheduledWorkoutSource.coach,
        status: ScheduledWorkoutStatus.planned,
      );
      final router = await mount(
        tester,
        overview(workouts: [coach], needsReview: true),
      );
      expect(find.text('Sesión de mi preparador'), findsOneWidget);
      expect(find.text('Sesión pautada por tu preparador'), findsOneWidget);
      expect(find.text('Dos planificaciones el mismo día'), findsNothing);
      await tester.ensureVisible(find.text('Ver sesión'));
      await tester.tap(find.text('Ver sesión'));
      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters['session'], 'coach');
    },
  );

  testWidgets(
    'inicio avisa de ambas planificaciones a 320 px con texto doble',
    (tester) async {
      await mount(
        tester,
        overview(
          workouts: [
            workout(ScheduledWorkoutStatus.planned),
            ScheduledWorkout(
              id: 'coach',
              templateId: 'private',
              templateName: 'Sesión de mi preparador',
              templateVersion: 1,
              scheduledDate: today,
              source: ScheduledWorkoutSource.coach,
              status: ScheduledWorkoutStatus.planned,
            ),
          ],
        ),
        width: 320,
        textScale: 2,
      );
      expect(find.text('Dos planificaciones el mismo día'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('2 sesiones en esta fecha'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('2 sesiones en esta fecha'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
        expect(find.text('Herramientas'), findsOneWidget);
        expect(find.text('Biblioteca de entrenamientos'), findsNothing);
        expect(find.text('Ver todas'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('la tarjeta de preparación abre su detalle como única entrada', (
    tester,
  ) async {
    final router = await mount(tester, overview());
    await tester.scrollUntilVisible(
      find.text('Ver preparación →'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ver preparación →'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/plan/goal/goal-1');
    expect(find.text('Preparación elegida'), findsOneWidget);
  });
  testWidgets(
    'Inicio muestra programas iniciados y actualiza su fase al volver',
    (tester) async {
      final repo = _HomePrograms();
      final router = await mount(
        tester,
        overview(),
        guided: repo,
        width: 320,
        textScale: 2,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Hipertrofia básica')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tus programas'), findsOneWidget);
      expect(find.byType(EntrenaProgramCard), findsNWidgets(2));
      // Compartir un tipo no basta: ambos deben mantener la composición compacta.
      for (final card in find.byType(EntrenaProgramCard).evaluate()) {
        final data = card.widget as EntrenaProgramCard;
        final finder = find.byWidget(data);
        final title = find.descendant(
          of: finder,
          matching: find.text(data.title),
        );
        final detail = find.descendant(
          of: finder,
          matching: find.text(data.detail),
        );
        expect(tester.getSize(finder).width, 250);
        expect(
          tester.getTopLeft(detail).dy - tester.getBottomLeft(title).dy,
          closeTo(6, 0.01),
        );
      }
      expect(
        tester.getTopLeft(find.text('Preparaciones')).dy,
        lessThan(tester.getTopLeft(find.text('Tus programas')).dy),
      );
      await tester.tap(find.text('Hipertrofia básica'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/library/programs/program');
      expect(find.text('Ficha del programa'), findsOneWidget);
      repo.items = [
        const StartedGuidedProgram(
          program: GuidedProgram(
            id: 'phased',
            name: 'Dominadas',
            mode: GuidedProgramMode.phased,
            phases: [
              GuidedPhase(name: 'Base', sessions: []),
              GuidedPhase(name: 'Progreso', sessions: []),
            ],
          ),
          phaseIndex: 1,
        ),
      ];
      router.pop();
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.text('Hipertrofia básica'), findsNothing);
      await tester.ensureVisible(find.text('Dominadas'));
      expect(find.text('Fase 2 de 2'), findsOneWidget);
      expect(repo.starts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Inicio ofrece añadir programa y actualiza sus tarjetas al volver',
    (tester) async {
      final repo = _HomePrograms()..items = [];
      final router = await mount(tester, overview(), guided: repo);
      expect(find.text('Tus programas'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('Añadir programa')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir programa'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/library?tab=programs');
      expect(find.text('Hipertrofia básica'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      final firstVisit = router.push<void>('/library/programs/program');
      await tester.pumpAndSettle();
      repo.items = [
        const StartedGuidedProgram(program: guidedFixture, phaseIndex: 0),
      ];
      router.pop();
      await firstVisit;
      await tester.pumpAndSettle();
      expect(find.text('Tus programas'), findsOneWidget);
      final secondVisit = router.push<void>('/library/programs/program');
      await tester.pumpAndSettle();
      repo.items = [];
      router.pop();
      await secondVisit;
      await tester.pumpAndSettle();
      expect(repo.calls, 4);
      expect(find.text('Tus programas'), findsOneWidget);
      expect(find.text('Añadir programa'), findsOneWidget);
    },
  );
  testWidgets(
    'Inicio conserva el tamaño de Preparaciones al pasar de añadir a programa iniciado',
    (tester) async {
      await tester.runAsync(() => loadReviewFont(always: true));
      const preparationName = 'Evaluación periódica FAS · Pruebas físicas';
      const programName = 'Glúteos · Empuje de cadera y sentadilla';
      final repo = _HomePrograms()..items = [];
      final router = await mount(
        tester,
        PreparationOverview(
          assessments: const [],
          preferences: null,
          goals: [
            PreparationGoal(
              id: 'goal-1',
              program: const PreparationProgram(
                id: PreparationProgramIds.fasPeriodicAssessment,
                name: preparationName,
                kind: PreparationProgramKind.internalAssessment,
              ),
              targetDate: DateTime(2027, 2, 14),
            ),
          ],
          weekStart: week,
          weeklyWorkouts: const [],
        ),
        guided: repo,
        width: 390,
      );
      Finder cardNamed(String title) => find.byWidgetPredicate(
        (widget) => widget is EntrenaProgramCard && widget.title == title,
      );
      final preparationSize = tester.getSize(cardNamed(preparationName));
      final emptySize = tester.getSize(cardNamed('Añadir programa'));
      expect(emptySize.width, preparationSize.width);
      expect(emptySize.height, closeTo(preparationSize.height, 0.1));

      // Reproduce el regreso a Inicio después de iniciar el programa del vídeo.
      final visit = router.push<void>('/library/programs/program');
      await tester.pumpAndSettle();
      repo.items = const [
        StartedGuidedProgram(
          program: GuidedProgram(
            id: 'program',
            name: programName,
            mode: GuidedProgramMode.guide,
            phases: [GuidedPhase(name: 'Rutina', sessions: [])],
          ),
          phaseIndex: 0,
        ),
      ];
      router.pop();
      await visit;
      await tester.pumpAndSettle();
      final startedSize = tester.getSize(cardNamed(programName));
      expect(startedSize.width, preparationSize.width);
      expect(startedSize.height, closeTo(preparationSize.height, 0.1));
      expect(tester.getSize(cardNamed(preparationName)), preparationSize);
      expect(find.text('Añadir programa'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
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
  testWidgets('volver del siguiente paso refresca Inicio una sola vez', (
    tester,
  ) async {
    final data = overview(needsReview: true);
    final source = _Overview(data);
    final router = await mount(tester, data, source: source);
    await tester.ensureVisible(find.text('Revisar lo pendiente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar lo pendiente'));
    await tester.pumpAndSettle();
    expect(source.calls, 1);
    router.pop();
    await tester.pumpAndSettle();
    expect(source.calls, 2);
  });
  testWidgets(
    'sin programa y con varias preparaciones no pide marcas de la primera',
    (tester) async {
      final router = await mount(
        tester,
        PreparationOverview(
          assessments: const [],
          preferences: null,
          goals: const [
            goal,
            PreparationGoal(
              id: 'second',
              program: PreparationProgram(
                id: 'troop',
                name: 'Tropa',
                kind: PreparationProgramKind.access,
              ),
            ),
          ],
          weekStart: week,
          weeklyWorkouts: const [],
        ),
      );
      expect(find.text('Elige una preparación'), findsOneWidget);
      expect(find.textContaining('Registra las marcas de'), findsNothing);
      await tester.ensureVisible(find.text('Ver preparaciones'));
      await tester.tap(find.text('Ver preparaciones'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/plan');
    },
  );
}

class _Overview implements GetPreparationOverviewUseCase {
  _Overview(this.overview);
  final PreparationOverview overview;
  int calls = 0;
  @override
  Future<PreparationOverview> call() async {
    calls++;
    return overview;
  }
}

class _HomePrograms extends GuidedTestRepository {
  int calls = 0;
  List<StartedGuidedProgram> items = [
    const StartedGuidedProgram(program: guidedFixture, phaseIndex: 0),
  ];
  @override
  Future<List<StartedGuidedProgram>> startedPrograms() async {
    calls++;
    return List.of(items);
  }
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

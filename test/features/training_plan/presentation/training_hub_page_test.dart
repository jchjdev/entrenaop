import '../../../helpers/performance_visual_review.dart';
import '../../../support/guided_program_fixture.dart';

import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';

import 'package:entrenaop/features/training_plan/domain/entities/training_context.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_hub_page.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';

const _goal = PreparationGoal(
  id: 'g',
  program: PreparationProgram(
    id: 'p',
    name: 'Preparación actual',
    kind: PreparationProgramKind.internalAssessment,
  ),
);
final _week = DateTime(2026, 10, 5);
AdaptiveProgramProgress _program(
  String status, {
  String id = 'g',
  String? name,
}) => AdaptiveProgramProgress(
  goalId: id,
  name: name ?? 'Preparación actual',
  status: status,
  message: 'Mensaje real del programa.',
);
PreparationOverview _overview({
  List<PreparationGoal> goals = const [_goal],
  List<AdaptiveProgramProgress> programs = const [],
  List<ScheduledWorkout> workouts = const [],
  TrainingContext? trainingContext,
}) => PreparationOverview(
  assessments: const [],
  trainingContext: trainingContext,
  preferences: null,
  goals: goals,
  weekStart: _week,
  weeklyWorkouts: workouts,
  programs: programs,
);
ScheduledWorkout _workout(
  String id,
  ScheduledWorkoutStatus status, {
  bool extra = false,
  bool coach = false,
}) => ScheduledWorkout(
  id: id,
  templateId: 't',
  templateName: 'Sesión $id',
  templateVersion: 1,
  scheduledDate: _week.add(const Duration(days: 2)),
  source: coach
      ? ScheduledWorkoutSource.coach
      : extra
      ? ScheduledWorkoutSource.user
      : ScheduledWorkoutSource.algorithm,
  preparationGoalId: extra ? null : 'g',
  status: status,
  executionId: status == ScheduledWorkoutStatus.inProgress
      ? 'execution-$id'
      : null,
);

void main() {
  setUpAll(loadReviewFont);

  Future<({GoRouter router, DashboardCubit cubit, _Overview source})> mount(
    WidgetTester tester,
    PreparationOverview data, {
    double width = 360,
    double height = 900,
    double textScale = 1,
    bool failInitially = false,
    String? section,
    DateTime? selectedDate,
    GuidedProgramRepository? guidedPrograms,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final source = _Overview(data)..fail = failInitially;
    final cubit = DashboardCubit(getOverview: source);
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/plan',
      routes: [
        GoRoute(
          path: '/plan',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: TrainingHubPage(
              initialSection: section,
              selectedDate: selectedDate,
              guidedPrograms: guidedPrograms,
            ),
          ),
        ),
        for (final path in [
          '/plan/week',
          '/plan/week/active/:id',
          '/plan/goal',
          '/plan/goal/:id',
          '/plan/goal/:id/training',
          '/profile/preferences',
          '/library',
          '/library/programs/:id',
          '/plan/goal/:id/troop-assessment',
          '/plan/goal/:id/periodic-assessment',
          '/plan/goal/:id/program-assessment',
        ])
          GoRoute(
            path: path,
            builder: (_, state) =>
                Scaffold(body: Text('Destino: ${state.uri}')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('review-boundary'),
        child: MaterialApp.router(
          theme: EntrenaTheme.dark,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (router: router, cubit: cubit, source: source);
  }

  Finder pane(String section) =>
      find.byKey(PageStorageKey('training-$section-scroll'));
  Finder inside(String section, Finder target) =>
      find.descendant(of: pane(section), matching: target);
  Future<void> select(WidgetTester tester, String label) async {
    final tab = find.widgetWithText(Tab, label);
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, String section, Finder target) async {
    final scrollable = find
        .descendant(of: pane(section), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      inside(section, target),
      180,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('abre Planes y conserva la agenda sin repetir la semana', (
    tester,
  ) async {
    final result = await mount(tester, _overview(goals: []));
    expect(find.text('Entrenar'), findsOneWidget);
    expect(
      find.text(
        'No hay plan automático en curso. Puedes seguir entrenando las sesiones de tu semana y los programas guiados.',
      ),
      findsOneWidget,
    );
    expect(find.text('Esta semana'), findsNothing);
    expect(find.text('Pendientes de esta semana'), findsNothing);
    expect(find.text('Registrar marcas'), findsNothing);
    expect(find.text('Crear y gestionar sesiones'), findsNothing);
    await tester.tap(find.text('Ver semana'));
    await tester.pumpAndSettle();
    expect(result.router.state.uri.path, '/plan/week');
    expect(result.router.state.uri.queryParameters['date'], '2026-10-05');
  });

  testWidgets('la fecha recibida llega intacta al mismo calendario', (
    tester,
  ) async {
    final result = await mount(
      tester,
      _overview(),
      selectedDate: DateTime(2026, 10, 7),
    );
    await tester.tap(find.text('Ver semana'));
    await tester.pumpAndSettle();
    expect(result.router.state.uri.toString(), '/plan/week?date=2026-10-07');
  });

  testWidgets(
    'pautas profesionales y biblioteca guiada no dependen de un plan automático',
    (tester) async {
      final guided = GuidedTestRepository();
      final result = await mount(
        tester,
        _overview(
          goals: [],
          workouts: [
            _workout('preparador', ScheduledWorkoutStatus.planned, coach: true),
          ],
        ),
        guidedPrograms: guided,
      );
      expect(
        find.text(
          'Las sesiones de tu preparador están disponibles en tu semana.',
        ),
        findsOneWidget,
      );
      await show(tester, 'plans', find.text('Hipertrofia básica'));
      await tester.tap(find.byKey(const ValueKey('training-guided-program')));
      await tester.pumpAndSettle();
      expect(result.router.state.uri.path, '/library/programs/program');
      expect(guided.starts, isEmpty);
    },
  );

  testWidgets('deslizar y tocar sincronizan las caras sin iniciar procesos', (
    tester,
  ) async {
    await mount(tester, _overview());
    await tester.drag(find.byType(TabBarView), const Offset(-310, 0));
    await tester.pumpAndSettle();
    expect(find.text('Tus preparaciones').hitTestable(), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    await select(tester, 'Disponibilidad');
    expect(
      find.text('Disponibilidad y material').hitTestable(),
      findsOneWidget,
    );
    await tester.drag(find.byType(TabBarView), const Offset(310, 0));
    await tester.pumpAndSettle();
    expect(find.text('Tus preparaciones').hitTestable(), findsOneWidget);
    await select(tester, 'Planes');
    expect(find.text('Plan automático').hitTestable(), findsOneWidget);
  });

  testWidgets(
    'preparaciones distingue programa actual, borrador, pausado y finalizado',
    (tester) async {
      final goals = ['training', 'draft', 'paused', 'complete']
          .map(
            (status) => PreparationGoal(
              id: status,
              program: PreparationProgram(
                id: status,
                name: 'Preparación $status',
                kind: PreparationProgramKind.internalAssessment,
              ),
            ),
          )
          .toList();
      await mount(
        tester,
        _overview(
          goals: goals,
          programs: [
            for (final status in ['training', 'draft', 'paused', 'complete'])
              _program(status, id: status),
          ],
        ),
        section: 'preparations',
      );
      for (final label in [
        'En curso',
        'Por configurar',
        'Pausada',
        'Finalizada',
      ]) {
        await show(tester, 'preparations', find.text(label));
        expect(inside('preparations', find.text(label)), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in ['training', 'needs_review', 'paused', 'complete']) {
    testWidgets(
      '$status conserva su destino y refresca una sola vez al volver',
      (tester) async {
        final result = await mount(
          tester,
          _overview(programs: [_program(status)]),
        );
        final label = status == 'training'
            ? 'Ver mi programa'
            : status == 'needs_review'
            ? 'Revisar lo pendiente'
            : 'Consultar programa';
        const section = 'plans';
        if (status == 'paused') {
          expect(find.textContaining('PROGRAMA EN CURSO'), findsNothing);
          expect(find.text('PLAN AUTOMÁTICO · Pausada'), findsOneWidget);
        }
        await show(tester, section, find.text(label));
        await tester.tap(inside(section, find.text(label)));
        await tester.pumpAndSettle();
        expect(
          result.router.state.uri.path,
          status == 'paused' || status == 'complete'
              ? '/plan/goal/g'
              : '/plan/goal/g/training',
        );
        result.router.pop();
        await tester.pumpAndSettle();
        expect(result.source.calls, 2);
        expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
      },
    );
  }

  testWidgets('volver del editor conserva cara, scroll y resumen ante fallo', (
    tester,
  ) async {
    final result = await mount(
      tester,
      _overview(programs: [_program('training')]),
      height: 480,
      section: 'availability',
    );
    await show(
      tester,
      'availability',
      find.text('Editar disponibilidad y material'),
    );
    final scrollable = find
        .descendant(of: pane('availability'), matching: find.byType(Scrollable))
        .first;
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    await tester.tap(find.text('Editar disponibilidad y material'));
    await tester.pumpAndSettle();
    expect(result.router.state.uri.path, '/profile/preferences');
    result.source.fail = true;
    result.router.pop();
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 2);
    expect(
      inside('availability', find.text('Reintentar cargar Entrenar')),
      findsOneWidget,
    );
    final after = tester.state<ScrollableState>(scrollable).position.pixels;
    // El aviso puede aumentar el contenido, pero no reinicia el scroll a cero.
    expect(after, greaterThanOrEqualTo(before));
    result.source.fail = false;
    await tester.drag(scrollable, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(
      inside(
        'availability',
        find.text('Reintentar cargar Entrenar'),
      ).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(
      inside('availability', find.text('Reintentar cargar Entrenar')),
    );
    await tester.pumpAndSettle();
    expect(
      inside('availability', find.text('Reintentar cargar Entrenar')),
      findsNothing,
    );
    expect(result.source.calls, 3);
  });

  testWidgets(
    'fallo inicial permite calendario y reintento en la cara solicitada',
    (tester) async {
      final result = await mount(
        tester,
        _overview(),
        failInitially: true,
        section: 'availability',
      );
      expect(find.text('Ver semana'), findsOneWidget);
      result.source.fail = false;
      await tester.tap(find.text('Reintentar cargar Entrenar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Disponibilidad y material').hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets('fallo inicial conserva reintento a 320 px con texto 2×', (
    tester,
  ) async {
    final result = await mount(
      tester,
      _overview(),
      failInitially: true,
      width: 320,
      height: 480,
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    result.source.fail = false;
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    final retry = find.text('Reintentar cargar Entrenar');
    expect(retry.hitTestable(), findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('Plan automático'), findsOneWidget);
  });

  for (final programId in [
    PreparationProgramIds.armedForcesTroopEntry,
    PreparationProgramIds.fasPeriodicAssessment,
    'generic',
  ]) {
    testWidgets(
      'ver $programId consulta su preparación sin evaluación implícita',
      (tester) async {
        final goal = PreparationGoal(
          id: 'g',
          program: PreparationProgram(
            id: programId,
            name: 'Pruebas',
            kind: PreparationProgramKind.internalAssessment,
          ),
        );
        final result = await mount(
          tester,
          _overview(goals: [goal]),
          section: 'preparations',
        );
        expect(find.text('Registrar marcas'), findsNothing);
        expect(find.text('Configurar programa'), findsNothing);
        await show(tester, 'preparations', find.text('Ver preparación'));
        await tester.tap(inside('preparations', find.text('Ver preparación')));
        await tester.pumpAndSettle();
        expect(result.router.state.uri.path, '/plan/goal/g');
      },
    );
  }

  for (final width in [320.0, 1100.0]) {
    for (final section in ['plans', 'preparations', 'availability']) {
      testWidgets('$section no desborda a $width px con texto 2×', (
        tester,
      ) async {
        await mount(
          tester,
          _overview(programs: [_program('needs_review')]),
          width: width,
          height: 480,
          textScale: 2,
          section: section,
        );
        if (section == 'availability') {
          await show(
            tester,
            section,
            find.text('Editar disponibilidad y material'),
          );
        }
        if (section == 'preparations') {
          await show(tester, section, find.text('Ver preparación'));
        }
        if (section == 'plans') {
          await show(tester, section, find.text('Revisar lo pendiente'));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'sin programa se pueden elegir todas las preparaciones guardadas',
    (tester) async {
      const second = PreparationGoal(
        id: 'second',
        program: PreparationProgram(
          id: 'second-p',
          name: 'Otra preparación',
          kind: PreparationProgramKind.access,
        ),
      );
      final result = await mount(tester, _overview(goals: [_goal, second]));
      await tester.tap(find.text('Ver preparaciones'));
      await tester.pumpAndSettle();
      await show(tester, 'preparations', find.text('Otra preparación'));
      await show(tester, 'preparations', find.text('Ver preparación').last);
      await tester.tap(
        inside('preparations', find.text('Ver preparación')).last,
      );
      await tester.pumpAndSettle();
      expect(result.router.state.uri.path, '/plan/goal/second');
    },
  );

  testWidgets(
    'disponibilidad presenta el contexto completo realmente guardado',
    (tester) async {
      await mount(
        tester,
        _overview(
          trainingContext: TrainingContext(
            availability: {'1': 45, '3': 60, '7': 0},
            equipment: {'pull_up_bar', 'resistance_band'},
            reportsPain: false,
            capacityConfirmed: true,
          ),
        ),
        section: 'availability',
      );
      expect(find.text('Lun 45 min · Mié 60 min'), findsOneWidget);
      expect(
        find.text('Material: barra de dominadas, banda de asistencia.'),
        findsOneWidget,
      );
      expect(find.textContaining('guardarlos no inicia'), findsOneWidget);
      await show(
        tester,
        'availability',
        find.text('Editar disponibilidad y material'),
      );
      await capturePerformanceWidget(tester, 'entrenar-contexto-guardado');
    },
  );

  testWidgets(
    'un fallo en programas guiados no bloquea el calendario ni el resumen',
    (tester) async {
      final guided = _FailedGuided();
      final result = await mount(
        tester,
        _overview(programs: [_program('training')]),
        guidedPrograms: guided,
      );
      await show(tester, 'plans', find.text('Reintentar programas'));
      expect(
        inside('plans', find.text('PLAN AUTOMÁTICO · En curso')),
        findsOneWidget,
      );
      await tester.tap(find.text('Ver semana'));
      await tester.pumpAndSettle();
      expect(result.router.state.uri.path, '/plan/week');
      expect(guided.starts, isEmpty);
    },
  );

  testWidgets(
    'Planes carga todas las páginas de programas seguidos y refresca al regresar',
    (tester) async {
      final guided = _PagedGuided();
      final result = await mount(tester, _overview(), guidedPrograms: guided);
      expect(guided.requests, [
        (page: 0, followed: true),
        (page: 1, followed: true),
      ]);
      await show(tester, 'plans', find.text('Programa guardado 4'));
      await tester.tap(find.byKey(const ValueKey('training-guided-saved-4')));
      await tester.pumpAndSettle();
      expect(result.router.state.uri.path, '/library/programs/saved-4');
      expect(guided.starts, isEmpty);
      result.router.pop();
      await tester.pumpAndSettle();
      expect(guided.requests, [
        (page: 0, followed: true),
        (page: 1, followed: true),
        (page: 0, followed: true),
        (page: 1, followed: true),
      ]);
    },
  );
}

class _Overview implements GetPreparationOverviewUseCase {
  _Overview(this.data);
  PreparationOverview data;
  bool fail = false;
  int calls = 0;
  @override
  Future<PreparationOverview> call() async {
    calls++;
    if (fail) throw StateError('offline');
    return data;
  }
}

class _FailedGuided extends GuidedTestRepository {
  @override
  Future<GuidedCatalogPage> catalog({
    String query = '',
    GuidedProgramMode? mode,
    int page = 0,
    int pageSize = 2,
    bool followed = false,
    String? categoryId,
  }) async => throw StateError('offline');
}

class _PagedGuided extends GuidedTestRepository {
  final requests = <({int page, bool followed})>[];
  @override
  Future<GuidedCatalogPage> catalog({
    String query = '',
    GuidedProgramMode? mode,
    int page = 0,
    int pageSize = 2,
    bool followed = false,
    String? categoryId,
  }) async {
    requests.add((page: page, followed: followed));
    return GuidedCatalogPage([
      for (final index in [page * 2 + 1, page * 2 + 2])
        GuidedProgram(
          id: 'saved-$index',
          name: 'Programa guardado $index',
          mode: GuidedProgramMode.guide,
          phases: guidedFixture.phases,
        ),
    ], hasMore: page == 0);
  }
}

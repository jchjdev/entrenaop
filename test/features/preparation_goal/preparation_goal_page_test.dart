import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_goal_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_program_page.dart';
import 'package:entrenaop/features/plan_preview/data/shared_preferences_plan_preview_store.dart';
import 'package:entrenaop/features/plan_preview/domain/plan_preview.dart';
import 'package:entrenaop/features/plan_preview/presentation/plan_preview_cubit.dart';
import 'package:entrenaop/features/plan_preview/presentation/plan_preview_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const troop = PreparationProgram(
    id: 'armed_forces_troop_entry',
    name: 'Ingreso · Tropa y marinería',
    kind: PreparationProgramKind.access,
  );
  const guard = PreparationProgram(
    id: 'guardia_civil_entry',
    name: 'Ingreso · Guardia Civil',
    kind: PreparationProgramKind.access,
  );

  testWidgets('Free consulta la ficha sin dar de alta y Pro permite añadir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preview = PlanPreviewCubit(
      enabled: true,
      store: SharedPreferencesPlanPreviewStore(
        await SharedPreferences.getInstance(),
      ),
    )..bindAccount('user');
    addTearDown(preview.close);
    await preview.select(PlanPreviewTier.free);
    final repository = _Repository(goals: [], programs: [troop]);
    final cubit = PreparationGoalCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/program',
      routes: [
        GoRoute(
          path: '/program',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: PreparationProgramPage(programId: troop.id),
          ),
        ),
        GoRoute(
          path: '/plan/pro',
          builder: (_, _) => const Scaffold(body: Text('Información de Pro')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      PlanPreviewScope(
        cubit: preview,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(troop.name), findsOneWidget);
    expect(find.text('Añadir preparación'), findsNothing);
    await tester.ensureVisible(find.text('Conocer Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conocer Pro'));
    await tester.pumpAndSettle();
    expect(find.text('Información de Pro'), findsOneWidget);
    expect(repository.goals, isEmpty);
    router.pop();
    await preview.select(PlanPreviewTier.pro);
    await tester.pumpAndSettle();
    expect(find.text('Añadir preparación'), findsOneWidget);
    expect(repository.goals, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'abrir un programa no convierte una fecha de agenda en una orden de cálculo',
    (tester) async {
      final cubit = PreparationGoalCubit(
        repository: _Repository(
          goals: const [PreparationGoal(id: 'goal-1', program: troop)],
          programs: const [troop],
        ),
      );
      await cubit.load();
      final router = GoRouter(
        initialLocation: '/catalog',
        routes: [
          GoRoute(
            path: '/catalog',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: PreparationGoalPage(trainingWeek: DateTime(2026, 10, 12)),
            ),
          ),
          GoRoute(
            path: '/plan/goal/:id/training',
            builder: (_, state) => Scaffold(
              body: Text(
                'Semana ${state.uri.queryParameters['week']} de ${state.pathParameters['id']}',
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(cubit.close);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ver mi programa'));
      await tester.tap(find.text('Ver mi programa'));
      await tester.pumpAndSettle();
      expect(find.text('Semana null de goal-1'), findsOneWidget);
    },
  );

  testWidgets('muestra el catálogo y permite añadir otra preparación', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _Repository(
      goals: const [PreparationGoal(id: 'goal-1', program: troop)],
      programs: const [troop, guard],
    );
    final cubit = PreparationGoalCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();
    final router = GoRouter(
      initialLocation: '/catalog',
      routes: [
        GoRoute(
          path: '/catalog',
          builder: (context, state) => BlocProvider.value(
            value: cubit,
            child: const PreparationGoalPage(),
          ),
        ),
        GoRoute(
          path: '/plan/program/:id',
          builder: (_, state) => BlocProvider.value(
            value: cubit,
            child: PreparationProgramPage(
              programId: state.pathParameters['id']!,
            ),
          ),
        ),
        GoRoute(
          path: '/plan/goal/:id',
          builder: (_, _) => const Scaffold(body: Text('Preparación creada')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData.dark(useMaterial3: true),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(troop.name), findsOneWidget);
    expect(find.text(guard.name), findsOneWidget);
    expect(find.text('Ver programa'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Ver programa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver programa'));
    await tester.pumpAndSettle();

    expect(cubit.state.goals, hasLength(1));
    expect(find.text('Cómo empezar'), findsOneWidget);
    await tester.ensureVisible(find.text('Añadir preparación'));
    await tester.tap(find.text('Añadir preparación'));
    await tester.pumpAndSettle();

    expect(cubit.state.goals, hasLength(2));
    expect(find.text('Preparación creada'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Ver programa'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements PreparationGoalRepository {
  _Repository({required this.goals, required this.programs});

  List<PreparationGoal> goals;
  final List<PreparationProgram> programs;

  @override
  Future<List<PreparationGoal>> getActiveGoals() async => goals;

  @override
  Future<List<PreparationProgram>> getAvailablePrograms() async => programs;

  @override
  Future<PreparationGoal> save(PreparationGoal goal) async {
    final saved = PreparationGoal(
      id: goal.id ?? 'goal-${goals.length + 1}',
      program: goal.program,
      targetDate: goal.targetDate,
    );
    goals = [
      for (final current in goals)
        if (current.programId != saved.programId) current,
      saved,
    ];
    return saved;
  }

  @override
  Future<void> archive(String goalId) async {
    goals = goals.where((goal) => goal.id != goalId).toList();
  }
}

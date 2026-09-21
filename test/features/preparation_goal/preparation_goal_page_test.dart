import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_goal_page.dart';
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
    expect(find.text('Añadir preparación'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Añadir preparación'));
    await tester.pumpAndSettle();

    expect(cubit.state.goals, hasLength(2));
    expect(find.text('Añadir preparación'), findsNothing);
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

import 'package:entrenaop/features/preparation_goal/data/models/preparation_goal_model.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const program = PreparationProgram(
    id: PreparationProgramIds.armedForcesTroopEntry,
    name: 'Ingreso · Tropa y marinería',
    kind: PreparationProgramKind.access,
    currentAssessmentCatalogVersion: 'es_def_15_2026_troop_v1',
  );
  const secondProgram = PreparationProgram(
    id: 'guardia_civil_entry',
    name: 'Ingreso · Guardia Civil',
    kind: PreparationProgramKind.access,
  );
  final goal = PreparationGoal(
    id: 'goal-1',
    program: program,
    targetDate: DateTime(2027, 2, 10),
  );

  test('convierte el objetivo entre dominio y base de datos', () {
    final json = PreparationGoalModel.toJson(goal, userId: 'user-1')
      ..['id'] = goal.id
      ..['preparation_programs'] = {
        'id': program.id,
        'name': program.name,
        'kind': 'access',
        'preparation_program_catalogs': [
          {'catalog_version': 'es_def_15_2026_troop_v1', 'is_current': true},
        ],
      };
    final restored = PreparationGoalModel.fromJson(json);

    expect(json['program_id'], 'armed_forces_troop_entry');
    expect(json['target_date'], '2027-02-10');
    expect(
      restored.program.currentAssessmentCatalogVersion,
      'es_def_15_2026_troop_v1',
    );
    expect(restored, goal);
  });

  test('el cubit carga y actualiza varias preparaciones', () async {
    final repository = _PreparationGoalRepository([goal], [program]);
    final cubit = PreparationGoalCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.status, PreparationGoalStatus.ready);
    expect(cubit.state.goals, [goal]);

    final updated = PreparationGoal(id: goal.id, program: goal.program);
    await cubit.updateTargetDate(updated, null);

    expect(repository.goals, [updated]);
    expect(cubit.state.status, PreparationGoalStatus.saved);
    expect(cubit.state.goals, [updated]);
  });

  test('añade preparaciones distintas y evita duplicar una activa', () async {
    final repository = _PreparationGoalRepository(const [], const [
      program,
      secondProgram,
    ]);
    final cubit = PreparationGoalCubit(repository: repository);
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.add(program);
    await cubit.add(secondProgram);
    await cubit.add(program);

    expect(cubit.state.goals.map((goal) => goal.program), {
      program,
      secondProgram,
    });
    expect(repository.saveCount, 2);
  });
}

class _PreparationGoalRepository implements PreparationGoalRepository {
  _PreparationGoalRepository(this.goals, this.programs);

  List<PreparationGoal> goals;
  final List<PreparationProgram> programs;
  int saveCount = 0;

  @override
  Future<List<PreparationGoal>> getActiveGoals() async => goals;

  @override
  Future<List<PreparationProgram>> getAvailablePrograms() async => programs;

  @override
  Future<PreparationGoal> save(PreparationGoal goal) async {
    saveCount += 1;
    goals = [
      for (final current in goals)
        if (current.programId != goal.programId) current,
      goal,
    ];
    return goal;
  }

  @override
  Future<void> archive(String goalId) async {
    goals = goals.where((goal) => goal.id != goalId).toList();
  }
}

import 'package:entrenaop/features/preparation_goal/data/models/preparation_goal_model.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final goal = PreparationGoal(
    id: 'goal-1',
    programId: PreparationProgramIds.armedForcesTroopEntry,
    targetDate: DateTime(2027, 2, 10),
  );

  test('convierte el objetivo entre dominio y base de datos', () {
    final json = PreparationGoalModel.toJson(goal, userId: 'user-1')
      ..['id'] = goal.id;
    final restored = PreparationGoalModel.fromJson(json);

    expect(json['program_id'], 'armed_forces_troop_entry');
    expect(json['target_date'], '2027-02-10');
    expect(restored, goal);
  });

  test('el cubit carga y guarda el objetivo activo', () async {
    final repository = _PreparationGoalRepository(goal);
    final cubit = PreparationGoalCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.status, PreparationGoalStatus.ready);
    expect(cubit.state.goal, goal);

    final updated = PreparationGoal(id: goal.id, programId: goal.programId);
    await cubit.save(updated);

    expect(repository.goal, updated);
    expect(cubit.state.status, PreparationGoalStatus.saved);
    expect(cubit.state.goal, updated);
  });
}

class _PreparationGoalRepository implements PreparationGoalRepository {
  _PreparationGoalRepository(this.goal);

  PreparationGoal? goal;

  @override
  Future<PreparationGoal?> getActive() async => goal;

  @override
  Future<PreparationGoal> save(PreparationGoal goal) async {
    this.goal = goal;
    return goal;
  }
}

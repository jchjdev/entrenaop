import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_state.dart';

class PreparationGoalCubit extends Cubit<PreparationGoalState> {
  PreparationGoalCubit({required PreparationGoalRepository repository})
    : _repository = repository,
      super(const PreparationGoalState());

  final PreparationGoalRepository _repository;

  Future<void> load() async {
    emit(const PreparationGoalState(status: PreparationGoalStatus.loading));
    try {
      final goalsFuture = _repository.getActiveGoals();
      final programsFuture = _repository.getAvailablePrograms();
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.ready,
          goals: await goalsFuture,
          programs: await programsFuture,
        ),
      );
    } catch (_) {
      emit(
        const PreparationGoalState(
          status: PreparationGoalStatus.failure,
          errorMessage: 'No hemos podido cargar tu objetivo.',
        ),
      );
    }
  }

  Future<void> add(PreparationProgram program) async {
    if (state.goals.any((goal) => goal.programId == program.id)) return;
    await _save(PreparationGoal(program: program));
  }

  Future<void> updateTargetDate(PreparationGoal goal, DateTime? targetDate) =>
      _save(
        PreparationGoal(
          id: goal.id,
          program: goal.program,
          targetDate: targetDate,
        ),
      );

  Future<void> archive(PreparationGoal goal) async {
    final goalId = goal.id;
    if (goalId == null) return;
    emit(
      PreparationGoalState(
        status: PreparationGoalStatus.saving,
        goals: state.goals,
        programs: state.programs,
      ),
    );
    try {
      await _repository.archive(goalId);
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.saved,
          goals: state.goals.where((item) => item.id != goalId).toList(),
          programs: state.programs,
        ),
      );
    } catch (_) {
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.failure,
          goals: state.goals,
          programs: state.programs,
          errorMessage: 'No hemos podido guardar tu objetivo.',
        ),
      );
    }
  }

  Future<void> _save(PreparationGoal goal) async {
    emit(
      PreparationGoalState(
        status: PreparationGoalStatus.saving,
        goals: state.goals,
        programs: state.programs,
      ),
    );
    try {
      final savedGoal = await _repository.save(goal);
      final updated = [
        for (final current in state.goals)
          if (current.programId != savedGoal.programId) current,
        savedGoal,
      ];
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.saved,
          goals: updated,
          programs: state.programs,
        ),
      );
    } catch (_) {
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.failure,
          goals: state.goals,
          programs: state.programs,
          errorMessage: 'No hemos podido guardar tu preparación.',
        ),
      );
    }
  }
}

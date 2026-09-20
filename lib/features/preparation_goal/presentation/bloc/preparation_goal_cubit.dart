import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
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
      final goal = await _repository.getActive();
      emit(
        PreparationGoalState(status: PreparationGoalStatus.ready, goal: goal),
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

  Future<void> save(PreparationGoal goal) async {
    emit(
      PreparationGoalState(
        status: PreparationGoalStatus.saving,
        goal: state.goal,
      ),
    );
    try {
      final savedGoal = await _repository.save(goal);
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.saved,
          goal: savedGoal,
        ),
      );
    } catch (_) {
      emit(
        PreparationGoalState(
          status: PreparationGoalStatus.failure,
          goal: state.goal,
          errorMessage: 'No hemos podido guardar tu objetivo.',
        ),
      );
    }
  }
}

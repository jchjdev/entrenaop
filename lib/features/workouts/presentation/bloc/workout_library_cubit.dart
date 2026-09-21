import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_library_state.dart';

class WorkoutLibraryCubit extends Cubit<WorkoutLibraryState> {
  WorkoutLibraryCubit({
    required GetPublicWorkoutsUseCase getPublicWorkouts,
    required GetPersonalWorkoutsUseCase getPersonalWorkouts,
  }) : _getPublicWorkouts = getPublicWorkouts,
       _getPersonalWorkouts = getPersonalWorkouts,
       super(const WorkoutLibraryState());

  final GetPublicWorkoutsUseCase _getPublicWorkouts;
  final GetPersonalWorkoutsUseCase _getPersonalWorkouts;

  Future<void> load() async {
    emit(
      WorkoutLibraryState(
        status: WorkoutLibraryStatus.loading,
        workouts: state.workouts,
        personalWorkouts: state.personalWorkouts,
      ),
    );
    try {
      final workouts = await _getPublicWorkouts();
      final personalWorkouts = await _getPersonalWorkouts();
      emit(
        WorkoutLibraryState(
          status: WorkoutLibraryStatus.ready,
          workouts: workouts,
          personalWorkouts: personalWorkouts,
        ),
      );
    } catch (_) {
      emit(
        WorkoutLibraryState(
          status: WorkoutLibraryStatus.failure,
          workouts: state.workouts,
          personalWorkouts: state.personalWorkouts,
          errorMessage: 'No hemos podido cargar la biblioteca.',
        ),
      );
    }
  }
}

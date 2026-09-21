import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_library_state.dart';

class WorkoutLibraryCubit extends Cubit<WorkoutLibraryState> {
  WorkoutLibraryCubit({required GetPublicWorkoutsUseCase getPublicWorkouts})
    : _getPublicWorkouts = getPublicWorkouts,
      super(const WorkoutLibraryState());

  final GetPublicWorkoutsUseCase _getPublicWorkouts;

  Future<void> load() async {
    emit(
      WorkoutLibraryState(
        status: WorkoutLibraryStatus.loading,
        workouts: state.workouts,
      ),
    );
    try {
      final workouts = await _getPublicWorkouts();
      emit(
        WorkoutLibraryState(
          status: WorkoutLibraryStatus.ready,
          workouts: workouts,
        ),
      );
    } catch (_) {
      emit(
        WorkoutLibraryState(
          status: WorkoutLibraryStatus.failure,
          workouts: state.workouts,
          errorMessage: 'No hemos podido cargar la biblioteca.',
        ),
      );
    }
  }
}

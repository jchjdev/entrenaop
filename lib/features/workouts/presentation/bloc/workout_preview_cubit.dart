import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_state.dart';

class WorkoutPreviewCubit extends Cubit<WorkoutPreviewState> {
  WorkoutPreviewCubit({required GetStarterWorkoutUseCase getStarterWorkout})
    : _getStarterWorkout = getStarterWorkout,
      super(const WorkoutPreviewState());

  final GetStarterWorkoutUseCase _getStarterWorkout;

  Future<void> load() async {
    emit(const WorkoutPreviewState(status: WorkoutPreviewStatus.loading));
    try {
      final workout = await _getStarterWorkout();
      emit(
        WorkoutPreviewState(
          status: workout == null
              ? WorkoutPreviewStatus.empty
              : WorkoutPreviewStatus.ready,
          workout: workout,
        ),
      );
    } catch (_) {
      emit(
        const WorkoutPreviewState(
          status: WorkoutPreviewStatus.failure,
          errorMessage: 'No hemos podido cargar la sesión.',
        ),
      );
    }
  }
}

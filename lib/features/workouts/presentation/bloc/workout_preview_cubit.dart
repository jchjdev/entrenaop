import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_state.dart';

class WorkoutPreviewCubit extends Cubit<WorkoutPreviewState> {
  WorkoutPreviewCubit({
    required GetStarterWorkoutUseCase getStarterWorkout,
    required StartWorkoutExecutionUseCase startExecution,
  }) : _getStarterWorkout = getStarterWorkout,
       _startExecution = startExecution,
       super(const WorkoutPreviewState());

  final GetStarterWorkoutUseCase _getStarterWorkout;
  final StartWorkoutExecutionUseCase _startExecution;

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

  Future<void> start() async {
    final workout = state.workout;
    if (workout == null) return;
    emit(
      WorkoutPreviewState(
        status: WorkoutPreviewStatus.starting,
        workout: workout,
      ),
    );
    try {
      final executionId = await _startExecution(workout.id);
      emit(
        WorkoutPreviewState(
          status: WorkoutPreviewStatus.ready,
          workout: workout,
          executionId: executionId,
        ),
      );
    } catch (_) {
      emit(
        WorkoutPreviewState(
          status: WorkoutPreviewStatus.failure,
          workout: workout,
          errorMessage: 'No hemos podido iniciar la sesión.',
        ),
      );
    }
  }
}

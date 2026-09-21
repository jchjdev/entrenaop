import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_library_state.dart';

class WorkoutLibraryCubit extends Cubit<WorkoutLibraryState> {
  WorkoutLibraryCubit({
    required GetPublicWorkoutsUseCase getPublicWorkouts,
    required GetPersonalWorkoutsUseCase getPersonalWorkouts,
    required DuplicatePersonalWorkoutUseCase duplicatePersonalWorkout,
    required ArchivePersonalWorkoutUseCase archivePersonalWorkout,
  }) : _getPublicWorkouts = getPublicWorkouts,
       _getPersonalWorkouts = getPersonalWorkouts,
       _duplicatePersonalWorkout = duplicatePersonalWorkout,
       _archivePersonalWorkout = archivePersonalWorkout,
       super(const WorkoutLibraryState());

  final GetPublicWorkoutsUseCase _getPublicWorkouts;
  final GetPersonalWorkoutsUseCase _getPersonalWorkouts;
  final DuplicatePersonalWorkoutUseCase _duplicatePersonalWorkout;
  final ArchivePersonalWorkoutUseCase _archivePersonalWorkout;

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

  Future<bool> duplicate(String templateId) async {
    emit(state.copyWith(busyTemplateId: templateId, clearError: true));
    try {
      await _duplicatePersonalWorkout(templateId);
      await load();
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          status: WorkoutLibraryStatus.failure,
          clearBusyTemplate: true,
          errorMessage: 'No hemos podido duplicar la sesión.',
        ),
      );
      return false;
    }
  }

  Future<bool> archive(String templateId) async {
    emit(state.copyWith(busyTemplateId: templateId, clearError: true));
    try {
      await _archivePersonalWorkout(templateId);
      await load();
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          status: WorkoutLibraryStatus.failure,
          clearBusyTemplate: true,
          errorMessage: 'No hemos podido archivar la sesión.',
        ),
      );
      return false;
    }
  }
}

import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_state.dart';

class WorkoutEditorCubit extends Cubit<WorkoutEditorState> {
  WorkoutEditorCubit({
    required GetExercisesUseCase getExercises,
    required CreatePersonalWorkoutUseCase createWorkout,
  }) : _getExercises = getExercises,
       _createWorkout = createWorkout,
       super(const WorkoutEditorState());

  final GetExercisesUseCase _getExercises;
  final CreatePersonalWorkoutUseCase _createWorkout;

  Future<void> load() async {
    emit(const WorkoutEditorState(status: WorkoutEditorStatus.loading));
    try {
      final exercises = await _getExercises();
      exercises.sort((a, b) => a.name.compareTo(b.name));
      emit(
        WorkoutEditorState(
          status: WorkoutEditorStatus.ready,
          exercises: exercises,
        ),
      );
    } catch (_) {
      emit(
        const WorkoutEditorState(
          status: WorkoutEditorStatus.failure,
          errorMessage: 'No hemos podido cargar el catálogo de ejercicios.',
        ),
      );
    }
  }

  Future<void> save(CreatePersonalWorkoutInput input) async {
    emit(
      WorkoutEditorState(
        status: WorkoutEditorStatus.saving,
        exercises: state.exercises,
      ),
    );
    try {
      final templateId = await _createWorkout(input);
      emit(
        WorkoutEditorState(
          status: WorkoutEditorStatus.saved,
          exercises: state.exercises,
          createdTemplateId: templateId,
        ),
      );
    } on FormatException catch (error) {
      emit(
        WorkoutEditorState(
          status: WorkoutEditorStatus.ready,
          exercises: state.exercises,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        WorkoutEditorState(
          status: WorkoutEditorStatus.ready,
          exercises: state.exercises,
          errorMessage:
              'No hemos podido guardar la sesión. Inténtalo de nuevo.',
        ),
      );
    }
  }
}

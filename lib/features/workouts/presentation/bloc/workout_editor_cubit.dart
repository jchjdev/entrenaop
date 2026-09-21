import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_state.dart';

class WorkoutEditorCubit extends Cubit<WorkoutEditorState> {
  WorkoutEditorCubit({
    required GetExercisesUseCase getExercises,
    required CreatePersonalWorkoutUseCase createWorkout,
    required GetWorkoutTemplateUseCase getWorkoutTemplate,
    required RevisePersonalWorkoutUseCase reviseWorkout,
    this.templateId,
  }) : _getExercises = getExercises,
       _createWorkout = createWorkout,
       _getWorkoutTemplate = getWorkoutTemplate,
       _reviseWorkout = reviseWorkout,
       super(const WorkoutEditorState());

  final GetExercisesUseCase _getExercises;
  final CreatePersonalWorkoutUseCase _createWorkout;
  final GetWorkoutTemplateUseCase _getWorkoutTemplate;
  final RevisePersonalWorkoutUseCase _reviseWorkout;
  final String? templateId;

  Future<void> load() async {
    emit(const WorkoutEditorState(status: WorkoutEditorStatus.loading));
    try {
      final exercises = [...await _getExercises()]
        ..sort((a, b) => a.name.compareTo(b.name));
      final originalTemplate = templateId == null
          ? null
          : await _getWorkoutTemplate(templateId!);
      if (templateId != null && originalTemplate == null) {
        throw StateError('Workout not found');
      }
      if (originalTemplate != null &&
          originalTemplate.blocks.any(
            (block) =>
                block.format != WorkoutBlockFormat.straightSets &&
                block.format != WorkoutBlockFormat.superset &&
                block.format != WorkoutBlockFormat.circuit &&
                block.format != WorkoutBlockFormat.intervals &&
                block.format != WorkoutBlockFormat.tabata,
          )) {
        throw StateError('Unsupported workout format');
      }
      emit(
        WorkoutEditorState(
          status: WorkoutEditorStatus.ready,
          exercises: exercises,
          originalTemplate: originalTemplate,
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
        originalTemplate: state.originalTemplate,
      ),
    );
    try {
      final savedTemplateId = templateId == null
          ? await _createWorkout(input)
          : await _reviseWorkout(templateId!, input);
      emit(
        WorkoutEditorState(
          status: WorkoutEditorStatus.saved,
          exercises: state.exercises,
          originalTemplate: state.originalTemplate,
          createdTemplateId: savedTemplateId,
        ),
      );
    } on FormatException catch (error) {
      emit(
        WorkoutEditorState(
          status: WorkoutEditorStatus.ready,
          exercises: state.exercises,
          originalTemplate: state.originalTemplate,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        WorkoutEditorState(
          status: WorkoutEditorStatus.ready,
          exercises: state.exercises,
          originalTemplate: state.originalTemplate,
          errorMessage:
              'No hemos podido guardar la sesión. Inténtalo de nuevo.',
        ),
      );
    }
  }
}

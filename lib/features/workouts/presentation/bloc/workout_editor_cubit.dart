import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/usecases/create_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/services/workout_editor_draft_store.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_state.dart';

class WorkoutEditorCubit extends Cubit<WorkoutEditorState> {
  WorkoutEditorCubit({
    required GetExercisesUseCase getExercises,
    required CreateExerciseUseCase createExercise,
    required WorkoutEditorDraftStore draftStore,
    required CreatePersonalWorkoutUseCase createWorkout,
    required GetWorkoutTemplateUseCase getWorkoutTemplate,
    required RevisePersonalWorkoutUseCase reviseWorkout,
    this.templateId,
    this.runningEditor = false,
    String? draftId,
  }) : _getExercises = getExercises,
       _createExercise = createExercise,
       _draftStore = draftStore,
       _createWorkout = createWorkout,
       _getWorkoutTemplate = getWorkoutTemplate,
       _reviseWorkout = reviseWorkout,
       _draftId = draftId ?? templateId ?? 'new',
       super(const WorkoutEditorState());

  final GetExercisesUseCase _getExercises;
  final CreateExerciseUseCase _createExercise;
  final WorkoutEditorDraftStore _draftStore;
  final CreatePersonalWorkoutUseCase _createWorkout;
  final GetWorkoutTemplateUseCase _getWorkoutTemplate;
  final RevisePersonalWorkoutUseCase _reviseWorkout;
  final String? templateId;
  final bool runningEditor;
  final String _draftId;

  Future<ExerciseEntity> createExercise(PersonalExerciseDraft draft) async {
    final created = await _createExercise(draft);
    final exercises = [...state.exercises, created]
      ..sort((a, b) => a.name.compareTo(b.name));
    emit(
      WorkoutEditorState(
        status: WorkoutEditorStatus.ready,
        exercises: exercises,
        originalTemplate: state.originalTemplate,
        draft: state.draft,
      ),
    );
    return created;
  }

  Future<void> load() async {
    emit(const WorkoutEditorState(status: WorkoutEditorStatus.loading));
    try {
      final exercises = [
        ...(await _getExercises()).where(
          (exercise) => exercise.id != runningExerciseId,
        ),
      ]..sort((a, b) => a.name.compareTo(b.name));
      final originalTemplate = templateId == null
          ? null
          : await _getWorkoutTemplate(templateId!);
      if (templateId != null && originalTemplate == null) {
        throw StateError('Workout not found');
      }
      if (originalTemplate != null &&
          originalTemplate.blocks.any(
                (block) => block.format == WorkoutBlockFormat.running,
              ) !=
              runningEditor) {
        throw StateError('Workout editor does not match template format');
      }
      if (originalTemplate != null &&
          originalTemplate.blocks.any(
            (block) =>
                block.format != WorkoutBlockFormat.straightSets &&
                block.format != WorkoutBlockFormat.superset &&
                block.format != WorkoutBlockFormat.circuit &&
                block.format != WorkoutBlockFormat.intervals &&
                block.format != WorkoutBlockFormat.tabata &&
                block.format != WorkoutBlockFormat.emom &&
                block.format != WorkoutBlockFormat.amrap &&
                (!runningEditor || block.format != WorkoutBlockFormat.running),
          )) {
        throw StateError('Unsupported workout format');
      }
      final draft = await _draftStore.read(_draftId);
      emit(
        WorkoutEditorState(
          status: WorkoutEditorStatus.ready,
          exercises: exercises,
          originalTemplate: originalTemplate,
          draft: draft,
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

  Future<void> persistDraft(CreatePersonalWorkoutInput input) =>
      _draftStore.write(
        _draftId,
        WorkoutEditorDraftSnapshot(input: input, savedAt: DateTime.now()),
      );

  Future<void> discardDraft() => _draftStore.clear(_draftId);

  Future<void> save(CreatePersonalWorkoutInput input) async {
    emit(
      WorkoutEditorState(
        status: WorkoutEditorStatus.saving,
        exercises: state.exercises,
        originalTemplate: state.originalTemplate,
        draft: state.draft,
      ),
    );
    try {
      final savedTemplateId = templateId == null
          ? await _createWorkout(input)
          : await _reviseWorkout(templateId!, input);
      await _draftStore.clear(_draftId);
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
          draft: state.draft,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        WorkoutEditorState(
          status: WorkoutEditorStatus.ready,
          exercises: state.exercises,
          originalTemplate: state.originalTemplate,
          draft: state.draft,
          errorMessage:
              'No hemos podido guardar la sesión. Inténtalo de nuevo.',
        ),
      );
    }
  }
}

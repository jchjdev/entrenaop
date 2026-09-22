import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_state.dart';
import 'package:flutter/foundation.dart';

class WorkoutPreviewCubit extends Cubit<WorkoutPreviewState> {
  WorkoutPreviewCubit({
    required this.templateId,
    required GetWorkoutTemplateUseCase getWorkoutTemplate,
    required StartWorkoutExecutionUseCase startExecution,
  }) : _getWorkoutTemplate = getWorkoutTemplate,
       _startExecution = startExecution,
       super(const WorkoutPreviewState());

  final String templateId;
  final GetWorkoutTemplateUseCase _getWorkoutTemplate;
  final StartWorkoutExecutionUseCase _startExecution;

  Future<void> load() async {
    emit(const WorkoutPreviewState(status: WorkoutPreviewStatus.loading));
    try {
      final workout = await _getWorkoutTemplate(templateId);
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
    } catch (error, stackTrace) {
      debugPrint('No se pudo iniciar la ejecución: $error');
      debugPrintStack(stackTrace: stackTrace);
      emit(
        WorkoutPreviewState(
          status: WorkoutPreviewStatus.failure,
          workout: workout,
          errorMessage: kDebugMode
              ? 'No hemos podido crear el registro.\n$error'
              : 'No hemos podido crear el registro.',
        ),
      );
    }
  }
}

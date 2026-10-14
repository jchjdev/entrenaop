import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercise_by_id_usecase.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_state.dart';
import 'package:flutter/foundation.dart';

class WorkoutPreviewCubit extends Cubit<WorkoutPreviewState> {
  WorkoutPreviewCubit({
    required this.templateId,
    required GetWorkoutTemplateUseCase getWorkoutTemplate,
    required StartWorkoutExecutionUseCase startExecution,
    GetExerciseByIdUseCase? getExercise,
  }) : _getWorkoutTemplate = getWorkoutTemplate,
       _getExercise = getExercise,
       _startExecution = startExecution,
       super(const WorkoutPreviewState());

  final String templateId;
  final GetWorkoutTemplateUseCase _getWorkoutTemplate;
  final StartWorkoutExecutionUseCase _startExecution;
  final GetExerciseByIdUseCase? _getExercise;
  int _loadRequest = 0;

  Future<void> load() async {
    final request = ++_loadRequest;
    emit(const WorkoutPreviewState(status: WorkoutPreviewStatus.loading));
    try {
      final workout = await _getWorkoutTemplate(templateId);
      if (isClosed || request != _loadRequest) return;
      emit(
        WorkoutPreviewState(
          status: workout == null
              ? WorkoutPreviewStatus.empty
              : WorkoutPreviewStatus.ready,
          workout: workout,
        ),
      );
      if (workout != null) unawaited(_loadThumbnails(workout, request));
    } catch (_) {
      if (isClosed || request != _loadRequest) return;
      emit(
        const WorkoutPreviewState(
          status: WorkoutPreviewStatus.failure,
          errorMessage: 'No hemos podido cargar la sesión.',
        ),
      );
    }
  }

  Future<void> _loadThumbnails(WorkoutTemplate workout, int request) async {
    final getExercise = _getExercise;
    if (getExercise == null) return;
    final ids = workout.blocks
        .expand((block) => block.items)
        .map((item) => item.exerciseId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    // Las fotos son accesorias: no retrasan el inicio ni consultan el catálogo
    // entero. Se reutilizan permisos/URLs firmadas y se acotan las lecturas.
    for (var offset = 0; offset < ids.length; offset += 4) {
      if (isClosed || request != _loadRequest) return;
      final images = await Future.wait(
        ids.skip(offset).take(4).map((id) async {
          try {
            final exercise = await getExercise(id)
                .timeout(const Duration(seconds: 10));
            final url = exercise?.thumbnailUrl?.trim();
            return url == null || url.isEmpty ? null : MapEntry(id, url);
          } catch (_) {
            return null;
          }
        }),
      );
      if (isClosed || request != _loadRequest) return;
      final available = images.whereType<MapEntry<String, String>>();
      if (available.isEmpty) continue;
      emit(
        WorkoutPreviewState(
          status: state.status,
          workout: state.workout,
          executionId: state.executionId,
          errorMessage: state.errorMessage,
          exerciseThumbnails: Map.unmodifiable({
            ...state.exerciseThumbnails,
            ...Map.fromEntries(available),
          }),
        ),
      );
    }
  }

  Future<void> start() async {
    final workout = state.workout;
    if (workout == null || state.status == WorkoutPreviewStatus.starting) {
      return;
    }
    emit(
      WorkoutPreviewState(
        status: WorkoutPreviewStatus.starting,
        workout: workout,
        exerciseThumbnails: state.exerciseThumbnails,
      ),
    );
    try {
      final executionId = await _startExecution(workout.id);
      if (isClosed) return;
      emit(
        WorkoutPreviewState(
          status: WorkoutPreviewStatus.ready,
          workout: workout,
          executionId: executionId,
          exerciseThumbnails: state.exerciseThumbnails,
        ),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      debugPrint('No se pudo iniciar la ejecución: $error');
      debugPrintStack(stackTrace: stackTrace);
      emit(
        WorkoutPreviewState(
          status: WorkoutPreviewStatus.failure,
          workout: workout,
          exerciseThumbnails: state.exerciseThumbnails,
          errorMessage: kDebugMode
              ? 'No hemos podido crear el registro.\n$error'
              : 'No hemos podido crear el registro.',
        ),
      );
    }
  }
}

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/scheduled_workout_preview.dart';
import '../../domain/usecases/scheduled_workout_preview_usecases.dart';

enum ScheduledWorkoutPreviewStatus {
  initial,
  loading,
  ready,
  starting,
  failure,
}

class ScheduledWorkoutPreviewState extends Equatable {
  const ScheduledWorkoutPreviewState({
    this.status = ScheduledWorkoutPreviewStatus.initial,
    this.preview,
    this.executionId,
    this.message,
    this.refreshRequired = false,
  });

  final ScheduledWorkoutPreviewStatus status;
  final ScheduledWorkoutPreview? preview;
  final String? executionId;
  final String? message;
  final bool refreshRequired;

  bool get busy =>
      status == ScheduledWorkoutPreviewStatus.loading ||
      status == ScheduledWorkoutPreviewStatus.starting;

  bool get canStart =>
      !busy &&
      !refreshRequired &&
      executionId == null &&
      preview?.canStart == true;

  @override
  List<Object?> get props => [
    status,
    preview,
    executionId,
    message,
    refreshRequired,
  ];
}

class ScheduledWorkoutPreviewCubit extends Cubit<ScheduledWorkoutPreviewState> {
  ScheduledWorkoutPreviewCubit({
    required this.scheduledId,
    required GetScheduledWorkoutPreviewUseCase getPreview,
    required StartReviewedScheduledWorkoutUseCase startReviewed,
  }) : _getPreview = getPreview,
       _startReviewed = startReviewed,
       super(const ScheduledWorkoutPreviewState());

  final String scheduledId;
  final GetScheduledWorkoutPreviewUseCase _getPreview;
  final StartReviewedScheduledWorkoutUseCase _startReviewed;
  int _request = 0;

  Future<void> load() => _load();

  Future<void> _load({bool changed = false}) async {
    if (isClosed || state.status == ScheduledWorkoutPreviewStatus.starting) {
      return;
    }
    final request = ++_request;
    final previous = state.preview;
    emit(
      ScheduledWorkoutPreviewState(
        status: ScheduledWorkoutPreviewStatus.loading,
        preview: previous,
        refreshRequired: true,
      ),
    );
    try {
      final preview = await _getPreview(scheduledId);
      if (isClosed || request != _request) return;
      emit(
        ScheduledWorkoutPreviewState(
          status: ScheduledWorkoutPreviewStatus.ready,
          preview: preview,
          message: !changed
              ? null
              : preview.hasResult
              ? 'Este entrenamiento ya tiene un resultado. Puedes consultarlo.'
              : preview.canStart
              ? 'El entrenamiento ha cambiado. Revisa lo pautado antes de comenzar.'
              : 'Este entrenamiento ya no está pendiente y no se puede comenzar.',
        ),
      );
    } catch (_) {
      if (isClosed || request != _request) return;
      emit(
        ScheduledWorkoutPreviewState(
          status: ScheduledWorkoutPreviewStatus.failure,
          preview: previous,
          refreshRequired: true,
          message: changed
              ? 'El entrenamiento ha cambiado y no hemos podido actualizarlo. Reintenta para consultar lo pautado.'
              : 'No hemos podido consultar este entrenamiento. Comprueba tu conexión y vuelve a intentarlo.',
        ),
      );
    }
  }

  Future<void> start() async {
    if (isClosed || !state.canStart) return;
    final preview = state.preview!;
    final request = ++_request;
    emit(
      ScheduledWorkoutPreviewState(
        status: ScheduledWorkoutPreviewStatus.starting,
        preview: preview,
      ),
    );
    try {
      final executionId = await _startReviewed(scheduledId, preview.revision);
      if (isClosed || request != _request) return;
      emit(
        ScheduledWorkoutPreviewState(
          status: ScheduledWorkoutPreviewStatus.ready,
          preview: preview,
          executionId: executionId,
        ),
      );
    } on ScheduledWorkoutPreviewChanged {
      if (isClosed || request != _request) return;
      // El servidor no inició nada: actualizar no sustituye el siguiente gesto.
      emit(
        ScheduledWorkoutPreviewState(
          status: ScheduledWorkoutPreviewStatus.ready,
          preview: preview,
          refreshRequired: true,
        ),
      );
      await _load(changed: true);
    } catch (_) {
      if (isClosed || request != _request) return;
      emit(
        ScheduledWorkoutPreviewState(
          status: ScheduledWorkoutPreviewStatus.failure,
          preview: preview,
          message:
              'No hemos podido comenzar el entrenamiento. Puedes reintentar.',
        ),
      );
    }
  }
}

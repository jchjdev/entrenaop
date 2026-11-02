import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/preparation_detail.dart';
import '../../domain/repositories/preparation_training_repository.dart';
import '../../domain/repositories/published_adaptive_week_repository.dart';
import '../../domain/usecases/get_preparation_detail_usecase.dart';
import '../../../workout_schedule/domain/entities/scheduled_workout.dart';

enum AdaptivePlanStatus { initial, loading, ready, failure }

class AdaptivePlanState extends Equatable {
  const AdaptivePlanState({
    required this.week,
    this.status = AdaptivePlanStatus.initial,
    this.setup,
    this.detail,
    this.published,
    this.error,
  });

  final DateTime week;
  final AdaptivePlanStatus status;
  final PreparationTrainingData? setup;
  final PreparationDetail? detail;
  final PublishedAdaptiveWeek? published;
  final String? error;

  List<DateTime> get weeks =>
      {week, ...?setup?.publishedWeeks.map(_monday)}.toList()
        ..sort((a, b) => b.compareTo(a));

  bool get paused => setup?.programState['status'] == 'paused';
  bool get needsReview => setup?.programState['status'] == 'needs_review';
  bool get complete => setup?.programState['status'] == 'complete';

  List<ScheduledWorkout> get workouts =>
      (detail?.weeklyWorkouts ?? const <ScheduledWorkout>[])
          .where(
            (item) =>
                item.preparationGoalId == detail?.goal.id &&
                item.source == ScheduledWorkoutSource.algorithm,
          )
          .toList()
        ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

  @override
  List<Object?> get props => [week, status, setup, detail, published, error];
}

/// Consulta las instantáneas publicadas. Abrir o cambiar semana nunca calcula,
/// avanza, activa ni comienza un entrenamiento.
class AdaptivePlanCubit extends Cubit<AdaptivePlanState> {
  AdaptivePlanCubit({
    required this.goalId,
    required PreparationTrainingRepository repository,
    required GetPreparationDetailUseCase getDetail,
    required PublishedAdaptiveWeekRepository publishedRepository,
    DateTime? initialWeek,
    DateTime Function()? now,
  }) : _repository = repository,
       _getDetail = getDetail,
       _publishedRepository = publishedRepository,
       _initialWeek = initialWeek == null ? null : _monday(initialWeek),
       super(AdaptivePlanState(week: _monday((now ?? DateTime.now)())));

  final String goalId;
  final PreparationTrainingRepository _repository;
  final GetPreparationDetailUseCase _getDetail;
  final PublishedAdaptiveWeekRepository _publishedRepository;
  final DateTime? _initialWeek;
  int _request = 0;

  Future<void> load({DateTime? week}) async {
    if (isClosed) return;
    final request = ++_request;
    final previous = state;
    final requestedWeek = week == null ? null : _monday(week);
    emit(
      AdaptivePlanState(
        week: requestedWeek ?? previous.week,
        status: AdaptivePlanStatus.loading,
        setup: previous.setup,
        detail: requestedWeek == null || requestedWeek == previous.week
            ? previous.detail
            : null,
        published: requestedWeek == null || requestedWeek == previous.week
            ? previous.published
            : null,
      ),
    );
    try {
      final setup = await _repository.load(goalId);
      if (isClosed || request != _request) return;
      final weeks = setup.publishedWeeks.map(_monday).toList()
        ..sort((a, b) => b.compareTo(a));
      final selected =
          requestedWeek ??
          (previous.setup != null ? previous.week : _initialWeek) ??
          weeks.firstOrNull ??
          previous.week;
      emit(
        AdaptivePlanState(
          week: selected,
          status: AdaptivePlanStatus.loading,
          setup: setup,
          detail: selected == previous.week ? previous.detail : null,
          published: selected == previous.week ? previous.published : null,
        ),
      );
      final detail = await _getDetail(
        goalId,
        selected,
        selected.add(const Duration(days: 6)),
      );
      if (isClosed || request != _request) return;
      if (detail.goal.id != goalId) {
        throw StateError('La preparación consultada no coincide.');
      }
      final published = await _publishedRepository.read(goalId, selected);
      if (isClosed || request != _request) return;
      emit(
        AdaptivePlanState(
          week: selected,
          status: AdaptivePlanStatus.ready,
          setup: setup,
          detail: detail,
          published: published,
        ),
      );
    } catch (_) {
      if (isClosed || request != _request) return;
      emit(
        AdaptivePlanState(
          week: state.week,
          status: AdaptivePlanStatus.failure,
          setup: state.setup,
          detail: state.detail,
          published: state.published,
          error: 'No hemos podido actualizar tu plan. Vuelve a intentarlo.',
        ),
      );
    }
  }
}

DateTime _monday(DateTime value) => DateTime(
  value.year,
  value.month,
  value.day,
).subtract(Duration(days: value.weekday - DateTime.monday));

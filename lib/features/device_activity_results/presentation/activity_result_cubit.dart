import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/activity_result.dart';

class ActivityResultState {
  const ActivityResultState({
    this.catalog,
    this.review,
    this.rows = const [],
    this.busy = false,
    this.problem,
    this.rpe,
    this.offsetMinutes,
    this.reviewed = false,
    this.executionId,
    this.retryingConfirmation = false,
  });
  final ActivityResultCatalog? catalog;
  final ActivityResultReview? review;
  final List<LapAssignment> rows;
  final bool busy, reviewed, retryingConfirmation;
  final String? problem, executionId;
  final int? rpe, offsetMinutes;
  bool get canConfirm =>
      !busy &&
      reviewed &&
      rpe != null &&
      rpe! >= 1 &&
      rpe! <= 10 &&
      offsetMinutes != null &&
      offsetMinutes!.abs() <= 840 &&
      review != null &&
      !review!.isTest &&
      review!.blockedReason == null &&
      (!review!.requiresMeasuredStep ||
          rows.any((r) => !r.skipped && r.laps.isNotEmpty)) &&
      validLapAssignments(rows, review!.laps);
}

class ActivityResultCubit extends Cubit<ActivityResultState> {
  ActivityResultCubit(this.repository, this.newOperation)
    : super(const ActivityResultState());
  final ActivityResultRepository repository;
  final String Function() newOperation;
  int _epoch = 0;
  ConfirmActivityResult? _pending;
  String _code(Object error) =>
      error is ActivityResultException ? error.code : 'activity_unavailable';
  Future<void> load() async {
    final epoch = ++_epoch;
    _pending = null;
    emit(const ActivityResultState(busy: true));
    try {
      final catalog = await repository.load();
      if (!isClosed && epoch == _epoch) {
        emit(ActivityResultState(catalog: catalog));
      }
    } catch (error) {
      if (!isClosed && epoch == _epoch) {
        emit(ActivityResultState(problem: _code(error)));
      }
    }
  }

  Future<void> preview(String activity, String scheduled) async {
    if (state.busy) return;
    final epoch = ++_epoch, catalog = state.catalog;
    _pending = null;
    emit(ActivityResultState(catalog: catalog, busy: true));
    try {
      final review = await repository.preview(activity, scheduled);
      if (!isClosed && epoch == _epoch) {
        emit(
          ActivityResultState(
            catalog: catalog,
            review: review,
            rows: List.unmodifiable(review.rows),
            offsetMinutes: review.offsetMinutes,
            rpe: review.recordedRpe,
          ),
        );
      }
    } catch (error) {
      if (!isClosed && epoch == _epoch) {
        emit(ActivityResultState(catalog: catalog, problem: _code(error)));
      }
    }
  }

  void edit({
    List<LapAssignment>? rows,
    int? rpe,
    int? offsetMinutes,
    bool? reviewed,
  }) {
    if (state.busy || _pending != null) return;
    emit(
      ActivityResultState(
        catalog: state.catalog,
        review: state.review,
        rows: rows == null ? state.rows : List.unmodifiable(rows),
        rpe: rpe ?? state.rpe,
        offsetMinutes: offsetMinutes ?? state.offsetMinutes,
        reviewed: reviewed ?? (rows == null && state.reviewed),
      ),
    );
  }

  Future<void> confirm() async {
    if (!state.canConfirm) return;
    final before = state, epoch = ++_epoch;
    _pending ??= ConfirmActivityResult(
      operationId: newOperation(),
      review: state.review!,
      rpe: state.rpe!,
      offsetMinutes: state.offsetMinutes!,
      rows: state.rows,
    );
    emit(
      ActivityResultState(
        catalog: before.catalog,
        review: before.review,
        rows: before.rows,
        rpe: before.rpe,
        offsetMinutes: before.offsetMinutes,
        reviewed: before.reviewed,
        busy: true,
        retryingConfirmation: true,
      ),
    );
    try {
      final execution = await repository.confirm(_pending!);
      if (!isClosed && epoch == _epoch) {
        emit(ActivityResultState(executionId: execution));
      }
    } catch (error) {
      if (!isClosed && epoch == _epoch) {
        emit(
          ActivityResultState(
            catalog: before.catalog,
            review: before.review,
            rows: before.rows,
            rpe: before.rpe,
            offsetMinutes: before.offsetMinutes,
            reviewed: before.reviewed,
            problem: _code(error),
            retryingConfirmation: true,
          ),
        );
      }
    }
  }
}

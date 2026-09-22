import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/workout_schedule/domain/usecases/workout_schedule_usecases.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_state.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';

class WorkoutScheduleCubit extends Cubit<WorkoutScheduleState> {
  WorkoutScheduleCubit({
    required GetWorkoutScheduleUseCase getSchedule,
    required ScheduleWorkoutUseCase scheduleWorkout,
    required RescheduleWorkoutUseCase rescheduleWorkout,
    required CancelScheduledWorkoutUseCase cancelWorkout,
    required StartScheduledWorkoutUseCase startWorkout,
    required GetPublicWorkoutsUseCase getPublicWorkouts,
    required GetPersonalWorkoutsUseCase getPersonalWorkouts,
    DateTime? initialDate,
    DateTime Function()? now,
  }) : _getSchedule = getSchedule,
       _scheduleWorkout = scheduleWorkout,
       _rescheduleWorkout = rescheduleWorkout,
       _cancelWorkout = cancelWorkout,
       _startWorkout = startWorkout,
       _getPublicWorkouts = getPublicWorkouts,
       _getPersonalWorkouts = getPersonalWorkouts,
       _now = now ?? DateTime.now,
       super(_initialState(initialDate ?? (now ?? DateTime.now)()));

  final GetWorkoutScheduleUseCase _getSchedule;
  final ScheduleWorkoutUseCase _scheduleWorkout;
  final RescheduleWorkoutUseCase _rescheduleWorkout;
  final CancelScheduledWorkoutUseCase _cancelWorkout;
  final StartScheduledWorkoutUseCase _startWorkout;
  final GetPublicWorkoutsUseCase _getPublicWorkouts;
  final GetPersonalWorkoutsUseCase _getPersonalWorkouts;
  final DateTime Function() _now;

  Future<void> load() async {
    emit(
      state.copyWith(status: WorkoutScheduleStatus.loading, clearError: true),
    );
    try {
      final items = await _getSchedule(state.weekStart, state.weekEnd);
      final publicTemplates = await _getPublicWorkouts();
      final personalTemplates = await _getPersonalWorkouts();
      emit(
        state.copyWith(
          status: WorkoutScheduleStatus.ready,
          items: items,
          publicTemplates: publicTemplates,
          personalTemplates: personalTemplates,
          clearBusy: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: WorkoutScheduleStatus.failure,
          clearBusy: true,
          errorMessage: 'No hemos podido cargar tu semana.',
        ),
      );
    }
  }

  void selectDay(DateTime day) {
    emit(state.copyWith(selectedDay: _dateOnly(day), clearError: true));
  }

  Future<void> changeWeek(int offset) async {
    final nextStart = state.weekStart.add(Duration(days: offset * 7));
    final today = _dateOnly(_now());
    final selected =
        !today.isBefore(nextStart) &&
            !today.isAfter(nextStart.add(const Duration(days: 6)))
        ? today
        : nextStart;
    emit(
      state.copyWith(
        weekStart: nextStart,
        selectedDay: selected,
        status: WorkoutScheduleStatus.loading,
        clearError: true,
      ),
    );
    await _reloadItems();
  }

  Future<bool> schedule(WorkoutTemplateSummary template) async {
    emit(state.copyWith(busyItemId: template.id, clearError: true));
    try {
      await _scheduleWorkout(template.id, state.selectedDay);
      await _reloadItems();
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          clearBusy: true,
          errorMessage: 'No hemos podido programar la sesión.',
        ),
      );
      return false;
    }
  }

  Future<bool> reschedule(String scheduledId, DateTime date) async {
    emit(state.copyWith(busyItemId: scheduledId, clearError: true));
    try {
      await _rescheduleWorkout(scheduledId, date);
      final nextWeek = _weekStart(date);
      emit(state.copyWith(weekStart: nextWeek, selectedDay: _dateOnly(date)));
      await _reloadItems();
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          clearBusy: true,
          errorMessage: 'No hemos podido reprogramar la sesión.',
        ),
      );
      return false;
    }
  }

  Future<bool> cancel(String scheduledId) async {
    emit(state.copyWith(busyItemId: scheduledId, clearError: true));
    try {
      await _cancelWorkout(scheduledId);
      await _reloadItems();
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          clearBusy: true,
          errorMessage: 'No hemos podido retirar la sesión.',
        ),
      );
      return false;
    }
  }

  Future<String?> start(String scheduledId) async {
    emit(state.copyWith(busyItemId: scheduledId, clearError: true));
    try {
      final executionId = await _startWorkout(scheduledId);
      await _reloadItems();
      return executionId;
    } catch (_) {
      emit(
        state.copyWith(
          clearBusy: true,
          errorMessage: 'No hemos podido iniciar la sesión programada.',
        ),
      );
      return null;
    }
  }

  Future<void> _reloadItems() async {
    try {
      final items = await _getSchedule(state.weekStart, state.weekEnd);
      emit(
        state.copyWith(
          status: WorkoutScheduleStatus.ready,
          items: items,
          clearBusy: true,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: WorkoutScheduleStatus.failure,
          clearBusy: true,
          errorMessage: 'No hemos podido actualizar tu semana.',
        ),
      );
    }
  }
}

WorkoutScheduleState _initialState(DateTime now) {
  final today = _dateOnly(now);
  return WorkoutScheduleState(weekStart: _weekStart(today), selectedDay: today);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _weekStart(DateTime value) =>
    _dateOnly(value).subtract(Duration(days: value.weekday - DateTime.monday));

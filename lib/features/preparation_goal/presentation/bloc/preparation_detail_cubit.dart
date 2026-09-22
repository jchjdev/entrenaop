import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_preparation_detail_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_state.dart';
import 'package:entrenaop/features/workout_schedule/domain/usecases/workout_schedule_usecases.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';

class PreparationDetailCubit extends Cubit<PreparationDetailState> {
  PreparationDetailCubit({
    required this.goalId,
    required GetPreparationDetailUseCase getDetail,
    required ScheduleWorkoutUseCase scheduleWorkout,
    required GetPublicWorkoutsUseCase getPublicWorkouts,
    required GetPersonalWorkoutsUseCase getPersonalWorkouts,
    DateTime Function()? now,
  }) : _getDetail = getDetail,
       _scheduleWorkout = scheduleWorkout,
       _getPublicWorkouts = getPublicWorkouts,
       _getPersonalWorkouts = getPersonalWorkouts,
       super(
         PreparationDetailState(weekStart: _weekStart((now ?? DateTime.now)())),
       );

  final String goalId;
  final GetPreparationDetailUseCase _getDetail;
  final ScheduleWorkoutUseCase _scheduleWorkout;
  final GetPublicWorkoutsUseCase _getPublicWorkouts;
  final GetPersonalWorkoutsUseCase _getPersonalWorkouts;

  Future<void> load() async {
    emit(
      state.copyWith(status: PreparationDetailStatus.loading, clearError: true),
    );
    try {
      final detail = await _getDetail(goalId, state.weekStart, state.weekEnd);
      final publicTemplates = await _getPublicWorkouts();
      final personalTemplates = await _getPersonalWorkouts();
      emit(
        state.copyWith(
          status: PreparationDetailStatus.ready,
          detail: detail,
          publicTemplates: publicTemplates,
          personalTemplates: personalTemplates,
          clearBusy: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PreparationDetailStatus.failure,
          clearBusy: true,
          errorMessage: 'No hemos podido abrir esta preparación.',
        ),
      );
    }
  }

  Future<void> changeWeek(int offset) async {
    emit(
      state.copyWith(
        weekStart: state.weekStart.add(Duration(days: offset * 7)),
        status: PreparationDetailStatus.loading,
        clearError: true,
      ),
    );
    await _reloadDetail();
  }

  Future<bool> schedule(WorkoutTemplateSummary template, DateTime date) async {
    emit(state.copyWith(busyTemplateId: template.id, clearError: true));
    try {
      await _scheduleWorkout(template.id, date, preparationGoalId: goalId);
      await _reloadDetail();
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          clearBusy: true,
          errorMessage: 'No hemos podido añadir la sesión a la preparación.',
        ),
      );
      return false;
    }
  }

  Future<void> _reloadDetail() async {
    try {
      final detail = await _getDetail(goalId, state.weekStart, state.weekEnd);
      emit(
        state.copyWith(
          status: PreparationDetailStatus.ready,
          detail: detail,
          clearBusy: true,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PreparationDetailStatus.failure,
          clearBusy: true,
          errorMessage: 'No hemos podido actualizar esta preparación.',
        ),
      );
    }
  }
}

DateTime _weekStart(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

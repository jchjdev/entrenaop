import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_preparation_detail_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_state.dart';

class PreparationDetailCubit extends Cubit<PreparationDetailState> {
  PreparationDetailCubit({
    required this.goalId,
    required GetPreparationDetailUseCase getDetail,
    DateTime Function()? now,
  }) : _getDetail = getDetail,
       super(
         PreparationDetailState(weekStart: _weekStart((now ?? DateTime.now)())),
       );

  final String goalId;
  final GetPreparationDetailUseCase _getDetail;

  Future<void> load() async {
    emit(
      state.copyWith(status: PreparationDetailStatus.loading, clearError: true),
    );
    try {
      final detail = await _getDetail(goalId, state.weekStart, state.weekEnd);
      emit(
        state.copyWith(status: PreparationDetailStatus.ready, detail: detail),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PreparationDetailStatus.failure,
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

  Future<void> _reloadDetail() async {
    try {
      final detail = await _getDetail(goalId, state.weekStart, state.weekEnd);
      emit(
        state.copyWith(
          status: PreparationDetailStatus.ready,
          detail: detail,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PreparationDetailStatus.failure,
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

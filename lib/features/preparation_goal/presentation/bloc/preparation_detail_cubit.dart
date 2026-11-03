import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/get_preparation_detail_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_state.dart';

class PreparationDetailCubit extends Cubit<PreparationDetailState> {
  PreparationDetailCubit({
    required this.goalId,
    required GetPreparationDetailUseCase getDetail,
    DateTime? initialWeek,
    DateTime Function()? now,
  }) : _getDetail = getDetail,
       super(
         PreparationDetailState(
           weekStart: _weekStart(initialWeek ?? (now ?? DateTime.now)()),
         ),
       );

  final String goalId;
  final GetPreparationDetailUseCase _getDetail;
  int _loadVersion = 0;

  Future<void> load() => _loadWeek(
    state.weekStart,
    errorMessage: 'No hemos podido abrir esta preparación.',
  );

  Future<void> changeWeek(int offset) => _loadWeek(
    // Se desplaza la fecha civil, no 168 horas: los cambios de horario no
    // deben convertir un lunes a medianoche en el domingo a las 23:00.
    DateTime(
      state.weekStart.year,
      state.weekStart.month,
      state.weekStart.day + offset * 7,
    ),
    errorMessage: 'No hemos podido actualizar esta preparación.',
  );

  Future<void> selectWeek(DateTime week) => _loadWeek(
    _weekStart(week),
    errorMessage: 'No hemos podido actualizar esta preparación.',
  );

  Future<void> _loadWeek(
    DateTime weekStart, {
    required String errorMessage,
  }) async {
    if (isClosed) return;
    final version = ++_loadVersion;
    // La respuesta solo pertenece a este intervalo. Una petición previa no
    // puede sustituir la semana que el deportista acaba de consultar.
    final weekEnd = weekStart.add(const Duration(days: 6));
    emit(
      state.copyWith(
        weekStart: weekStart,
        status: PreparationDetailStatus.loading,
        clearError: true,
        // Un refresco conserva la misma consulta; otro intervalo debe esperar
        // sus propios datos, también cuando la respuesta termine en error.
        clearDetail: state.detail?.weekStart != weekStart,
      ),
    );
    try {
      final detail = await _getDetail(goalId, weekStart, weekEnd);
      if (isClosed || version != _loadVersion) return;
      emit(
        state.copyWith(
          status: PreparationDetailStatus.ready,
          detail: detail,
          clearError: true,
        ),
      );
    } catch (_) {
      if (isClosed || version != _loadVersion) return;
      emit(
        state.copyWith(
          status: PreparationDetailStatus.failure,
          errorMessage: errorMessage,
        ),
      );
    }
  }
}

DateTime _weekStart(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

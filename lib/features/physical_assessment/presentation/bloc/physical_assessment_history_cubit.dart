import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_progress_calculator.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/get_physical_assessment_history_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_state.dart';

class PhysicalAssessmentHistoryCubit
    extends Cubit<PhysicalAssessmentHistoryState> {
  PhysicalAssessmentHistoryCubit({
    required GetPhysicalAssessmentHistoryUseCase getHistory,
    required AssessmentProgressCalculator progressCalculator,
  }) : _getHistory = getHistory,
       _progressCalculator = progressCalculator,
       super(const PhysicalAssessmentHistoryState());

  final GetPhysicalAssessmentHistoryUseCase _getHistory;
  final AssessmentProgressCalculator _progressCalculator;

  Future<void> load() async {
    emit(
      const PhysicalAssessmentHistoryState(
        status: PhysicalAssessmentHistoryStatus.loading,
      ),
    );

    try {
      final entries = await _getHistory();
      final List<AssessmentProgress> progress = entries.length < 2
          ? const <AssessmentProgress>[]
          : _progressCalculator.compare(
              previous: entries[1],
              current: entries[0],
            );

      emit(
        PhysicalAssessmentHistoryState(
          status: PhysicalAssessmentHistoryStatus.loaded,
          entries: entries,
          progress: progress,
        ),
      );
    } catch (_) {
      emit(
        const PhysicalAssessmentHistoryState(
          status: PhysicalAssessmentHistoryStatus.failure,
          errorMessage:
              'No hemos podido cargar tu historial. Revisa la conexión e inténtalo de nuevo.',
        ),
      );
    }
  }
}

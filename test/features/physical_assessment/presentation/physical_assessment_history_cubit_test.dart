import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_progress_calculator.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/get_physical_assessment_history_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('carga el historial vacío como un resultado válido', () async {
    final cubit = PhysicalAssessmentHistoryCubit(
      getHistory: GetPhysicalAssessmentHistoryUseCase(_HistoryRepository()),
      progressCalculator: const AssessmentProgressCalculator(),
    );

    await cubit.load();

    expect(cubit.state.status, PhysicalAssessmentHistoryStatus.loaded);
    expect(cubit.state.entries, isEmpty);
    await cubit.close();
  });

  test('expone un error recuperable cuando falla la lectura', () async {
    final cubit = PhysicalAssessmentHistoryCubit(
      getHistory: GetPhysicalAssessmentHistoryUseCase(
        _HistoryRepository(shouldFail: true),
      ),
      progressCalculator: const AssessmentProgressCalculator(),
    );

    await cubit.load();

    expect(cubit.state.status, PhysicalAssessmentHistoryStatus.failure);
    expect(cubit.state.errorMessage, isNotEmpty);
    await cubit.close();
  });
}

class _HistoryRepository implements PhysicalAssessmentRepository {
  _HistoryRepository({this.shouldFail = false});

  final bool shouldFail;

  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistory() async {
    if (shouldFail) throw Exception('Fallo simulado');
    return const [];
  }

  @override
  Future<String> saveAssessment(
    AssessmentReport report, {
    DateTime? completedAt,
  }) {
    throw UnimplementedError();
  }
}

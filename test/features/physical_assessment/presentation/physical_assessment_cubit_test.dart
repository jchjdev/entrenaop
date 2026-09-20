import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_evaluator.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/evaluate_initial_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/save_physical_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guarda el informe evaluado y conserva su identificador', () async {
    final repository = _FakePhysicalAssessmentRepository();
    final cubit = _buildCubit(repository);

    cubit.evaluate(_entryMarks);
    await cubit.save();

    expect(cubit.state.status, PhysicalAssessmentStatus.saved);
    expect(cubit.state.savedAssessmentId, 'assessment-123');
    expect(repository.savedReport, cubit.state.report);

    await cubit.close();
  });

  test('permite reintentar sin perder el informe cuando falla', () async {
    final repository = _FakePhysicalAssessmentRepository(shouldFail: true);
    final cubit = _buildCubit(repository);

    cubit.evaluate(_entryMarks);
    final report = cubit.state.report;
    await cubit.save();

    expect(cubit.state.status, PhysicalAssessmentStatus.failure);
    expect(cubit.state.report, report);
    expect(cubit.state.errorMessage, isNotEmpty);

    await cubit.close();
  });
}

PhysicalAssessmentCubit _buildCubit(PhysicalAssessmentRepository repository) {
  return PhysicalAssessmentCubit(
    evaluateInitialAssessment: const EvaluateInitialAssessmentUseCase(
      AssessmentEvaluator(),
    ),
    savePhysicalAssessment: SavePhysicalAssessmentUseCase(repository),
  );
}

const _entryMarks = [
  RecordedMark(
    testId: 'upper_body_push_ups_2_min',
    unit: MarkUnit.repetitions,
    value: 9,
  ),
  RecordedMark(
    testId: 'abdominal_plank',
    unit: MarkUnit.milliseconds,
    value: 40000,
  ),
  RecordedMark(
    testId: 'run_2000_m',
    unit: MarkUnit.milliseconds,
    value: 714000,
  ),
  RecordedMark(
    testId: 'agility_speed_circuit',
    unit: MarkUnit.milliseconds,
    value: 15400,
  ),
];

class _FakePhysicalAssessmentRepository
    implements PhysicalAssessmentRepository {
  _FakePhysicalAssessmentRepository({this.shouldFail = false});

  final bool shouldFail;
  AssessmentReport? savedReport;

  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistory() async => const [];

  @override
  Future<String> saveAssessment(
    AssessmentReport report, {
    DateTime? completedAt,
  }) async {
    savedReport = report;
    if (shouldFail) throw Exception('Fallo simulado');
    return 'assessment-123';
  }
}

import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/evaluate_initial_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_state.dart';

class PhysicalAssessmentCubit extends Cubit<PhysicalAssessmentState> {
  PhysicalAssessmentCubit({
    required EvaluateInitialAssessmentUseCase evaluateInitialAssessment,
  }) : _evaluateInitialAssessment = evaluateInitialAssessment,
       super(const PhysicalAssessmentState());

  final EvaluateInitialAssessmentUseCase _evaluateInitialAssessment;

  void selectCategory(AssessmentCategory category) {
    // Un resultado calculado con H no sigue siendo válido al pasar a M (o al
    // contrario), por lo que cualquier informe anterior debe descartarse.
    emit(
      state.copyWith(
        category: category,
        status: PhysicalAssessmentStatus.editing,
        clearReport: true,
      ),
    );
  }

  void evaluate(List<RecordedMark> marks) {
    final report = _evaluateInitialAssessment(
      category: state.category,
      marks: marks,
    );
    emit(
      state.copyWith(
        status: PhysicalAssessmentStatus.evaluated,
        report: report,
      ),
    );
  }

  void editAgain() {
    emit(
      state.copyWith(
        status: PhysicalAssessmentStatus.editing,
        clearReport: true,
      ),
    );
  }
}

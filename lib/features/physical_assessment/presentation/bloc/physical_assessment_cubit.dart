import 'package:bloc/bloc.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/evaluate_initial_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/save_physical_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_state.dart';

class PhysicalAssessmentCubit extends Cubit<PhysicalAssessmentState> {
  PhysicalAssessmentCubit({
    required EvaluateInitialAssessmentUseCase evaluateInitialAssessment,
    required SavePhysicalAssessmentUseCase savePhysicalAssessment,
  }) : _evaluateInitialAssessment = evaluateInitialAssessment,
       _savePhysicalAssessment = savePhysicalAssessment,
       super(const PhysicalAssessmentState());

  final EvaluateInitialAssessmentUseCase _evaluateInitialAssessment;
  final SavePhysicalAssessmentUseCase _savePhysicalAssessment;

  void selectCategory(AssessmentCategory category) {
    // Un resultado calculado con H no sigue siendo válido al pasar a M (o al
    // contrario), por lo que cualquier informe anterior debe descartarse.
    emit(
      state.copyWith(
        category: category,
        status: PhysicalAssessmentStatus.editing,
        clearReport: true,
        clearSavedAssessment: true,
        clearError: true,
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
        clearSavedAssessment: true,
        clearError: true,
      ),
    );
  }

  Future<void> save() async {
    final report = state.report;
    if (report == null || state.status == PhysicalAssessmentStatus.saving) {
      return;
    }

    emit(
      state.copyWith(status: PhysicalAssessmentStatus.saving, clearError: true),
    );

    try {
      final assessmentId = await _savePhysicalAssessment(report);
      emit(
        state.copyWith(
          status: PhysicalAssessmentStatus.saved,
          savedAssessmentId: assessmentId,
        ),
      );
    } catch (_) {
      // El detalle técnico queda fuera de la interfaz. El usuario recibe una
      // acción recuperable y puede reintentar sin perder las marcas.
      emit(
        state.copyWith(
          status: PhysicalAssessmentStatus.failure,
          errorMessage:
              'No hemos podido guardar la evaluación. Revisa la conexión e inténtalo de nuevo.',
        ),
      );
    }
  }

  void editAgain() {
    emit(
      state.copyWith(
        status: PhysicalAssessmentStatus.editing,
        clearReport: true,
        clearSavedAssessment: true,
        clearError: true,
      ),
    );
  }
}

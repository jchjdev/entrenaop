import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_progress_calculator.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/get_physical_assessment_history_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/physical_assessment_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el historial cabe en una pantalla móvil', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cubit = PhysicalAssessmentHistoryCubit(
      getHistory: GetPhysicalAssessmentHistoryUseCase(_Repository()),
      progressCalculator: const AssessmentProgressCalculator(),
    );
    await cubit.load();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: BlocProvider.value(
          value: cubit,
          child: const PhysicalAssessmentHistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evaluación física · Tropa'), findsOneWidget);
    expect(find.text('Repetir evaluación'), findsOneWidget);
    expect(find.text('Ya tienes tu primera referencia'), findsOneWidget);
    expect(find.text('Foco recomendado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements PhysicalAssessmentRepository {
  @override
  Future<List<PhysicalAssessmentHistoryEntry>> getHistory() async {
    const test = PhysicalTestDefinition(
      id: 'upper_body_push_ups_2_min',
      name: 'Flexo-extensiones de brazos (2 min)',
      unit: MarkUnit.repetitions,
      betterDirection: BetterDirection.higher,
    );

    return [
      PhysicalAssessmentHistoryEntry(
        id: 'assessment-1',
        completedAt: DateTime(2026, 9, 20, 8, 12),
        recommendation: const AssessmentFocusRecommendation(
          algorithmVersion: 'assessment_focus_v1',
          focusTestId: 'upper_body_push_ups_2_min',
          relativeMarginBps: -1200,
          reason: AssessmentFocusReason.belowMinimum,
        ),
        report: AssessmentReport(
          catalogVersion: 'catalog-v1',
          category: AssessmentCategory.men,
          milestone: AssessmentMilestone.entry,
          results: const [
            AssessmentResult(
              passed: true,
              mark: RecordedMark(
                testId: 'upper_body_push_ups_2_min',
                unit: MarkUnit.repetitions,
                value: 10,
              ),
              standard: AssessmentStandard(
                catalogVersion: 'catalog-v1',
                test: test,
                category: AssessmentCategory.men,
                milestone: AssessmentMilestone.entry,
                threshold: 9,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Future<String> saveAssessment(
    AssessmentReport report, {
    DateTime? completedAt,
  }) {
    throw UnimplementedError();
  }
}

import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_evaluator.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/evaluate_initial_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/save_physical_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/initial_assessment_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements PhysicalAssessmentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'Tropa se rellena con dígitos y conserva segundos y milésimas al evaluar',
    (tester) async {
      final cubit = PhysicalAssessmentCubit(
        evaluateInitialAssessment: const EvaluateInitialAssessmentUseCase(
          AssessmentEvaluator(),
        ),
        savePhysicalAssessment: SavePhysicalAssessmentUseCase(_Repository()),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const InitialAssessmentPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      for (final entry in [(0, '25'), (1, '30'), (2, '1130'), (3, '15,250')]) {
        await tester.ensureVisible(fields.at(entry.$1));
        await tester.enterText(fields.at(entry.$1), entry.$2);
      }
      expect(
        tester.widget<TextFormField>(fields.at(1)).controller!.text,
        '00:30',
      );
      expect(
        tester.widget<TextFormField>(fields.at(2)).controller!.text,
        '11:30',
      );
      expect(
        tester.widget<TextFormField>(fields.at(3)).controller!.text,
        '15,250',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Evaluar mis marcas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evaluar mis marcas'));
      await tester.pumpAndSettle();
      final marks = {
        for (final result in cubit.state.report!.results)
          result.mark.testId: result.mark.value,
      };
      expect(marks['abdominal_plank'], 30000);
      expect(marks['run_2000_m'], 690000);
      expect(marks['agility_speed_circuit'], 15250);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_assessment_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la agilidad desaparece desde los 45 años sin derivar a Tropa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: FasPeriodicAssessmentPage(
          goalId: 'goal-fas',
          repository: repository,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Evaluación periódica FAS · 2027'), findsOneWidget);
    final age = find.widgetWithText(TextFormField, 'Edad en la fecha del test');
    await tester.enterText(age, '44');
    await tester.pumpAndSettle();
    expect(
      find.text('El circuito de agilidad no es obligatorio desde los 45 años.'),
      findsNothing,
    );

    await tester.enterText(age, '45');
    await tester.pumpAndSettle();
    expect(
      find.text('El circuito de agilidad no es obligatorio desde los 45 años.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Flexo-extensiones en 2 min'),
      '10',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Plancha'), '33');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Carrera 2.000 m'),
      '12:18',
    );
    final button = find.text('Guardar resultado del test');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(repository.savedGoalId, 'goal-fas');
    expect(repository.savedAge, 45);
    expect(repository.savedMarks, {
      'upper_body_push_ups_2_min': 10,
      'abdominal_plank': 33000,
      'run_2000_m': 738000,
    });
  });
}

class _FakeRepository implements FasPeriodicAssessmentRepository {
  String? savedGoalId;
  int? savedAge;
  Map<String, int>? savedMarks;

  @override
  Future<List<FasPeriodicAssessmentEntry>> history(String goalId) async => [];

  @override
  Future<String> save({
    required String goalId,
    required String category,
    required int age,
    required Map<String, int> marks,
  }) async {
    savedGoalId = goalId;
    savedAge = age;
    savedMarks = marks;
    return 'saved';
  }
}

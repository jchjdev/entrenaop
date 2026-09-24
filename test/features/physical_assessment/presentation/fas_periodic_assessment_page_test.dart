import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_assessment_page.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FasPeriodic2027Reference reference;
  setUpAll(() async => reference = await FasPeriodic2027Reference.load());

  testWidgets('pide nacimiento antes de mostrar el baremo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FasPeriodicAssessmentPage(
          goalId: 'goal-fas',
          repository: _FakeRepository(),
          birthDateRepository: _FakeBirthDateRepository(null),
          reference: reference,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Indica tu fecha de nacimiento'), findsOneWidget);
    expect(find.text('Guardar resultado del test'), findsNothing);
  });

  testWidgets('la agilidad desaparece desde los 45 años sin derivar a Tropa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeRepository();
    final today = DateTime.now();
    final profile = _FakeBirthDateRepository(
      DateTime(today.year - 44, today.month, today.day),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FasPeriodicAssessmentPage(
          goalId: 'goal-fas',
          repository: repository,
          birthDateRepository: profile,
          reference: reference,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Evaluación periódica FAS · 2027'), findsOneWidget);
    expect(find.text('44 años · baremo según tu edad actual'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Circuito de agilidad'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Circuito de agilidad'), findsOneWidget);
    expect(
      find.text('El circuito de agilidad no es obligatorio desde los 45 años.'),
      findsNothing,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FasPeriodicAssessmentPage(
          key: const ValueKey('age-45'),
          goalId: 'goal-fas',
          repository: repository,
          birthDateRepository: _FakeBirthDateRepository(
            DateTime(today.year - 45, today.month, today.day),
          ),
          reference: reference,
        ),
      ),
    );
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

class _FakeBirthDateRepository implements ProfileBirthDateRepository {
  _FakeBirthDateRepository(this.value);

  DateTime? value;

  @override
  Future<DateTime?> get() async => value;

  @override
  Future<void> save(DateTime birthDate) async => value = birthDate;
}

class _FakeRepository implements FasPeriodicAssessmentRepository {
  String? savedGoalId;
  int? savedAge;
  Map<String, int>? savedMarks;

  @override
  Future<List<FasPeriodicAssessmentEntry>> history({String? goalId}) async =>
      [];

  @override
  Future<String> save({
    String? goalId,
    required String category,
    required int age,
    required Map<String, int> marks,
    DateTime? completedAt,
  }) async {
    savedGoalId = goalId;
    savedAge = age;
    savedMarks = marks;
    return 'saved';
  }
}

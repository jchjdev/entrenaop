import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_calculator_page.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FasPeriodic2027Reference reference;
  setUpAll(() async => reference = await FasPeriodic2027Reference.load());

  testWidgets('calcula cuatro puntuaciones sin guardar un intento', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profile = _BirthDateRepository(DateTime(2001, 1, 1));

    await tester.pumpWidget(
      MaterialApp(
        home: FasPeriodicCalculatorPage(
          birthDateRepository: profile,
          repository: _Repository(),
          reference: reference,
          today: DateTime(2026, 9, 24),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Referencia futura: este baremo de evaluación periódica entra en vigor el 01/01/2027.',
      ),
      findsOneWidget,
    );
    expect(find.text('H · hombres'), findsOneWidget);
    expect(find.text('M · mujeres'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('fas-mark-upper_body_push_ups_2_min')),
      '14',
    );
    await tester.enterText(
      find.byKey(const ValueKey('fas-mark-abdominal_plank')),
      '40',
    );
    final runField = find.byKey(const ValueKey('fas-mark-run_2000_m'));
    await tester.enterText(runField, '1146');
    expect(tester.widget<TextFormField>(runField).controller!.text, '11:46');
    await tester.enterText(
      find.byKey(const ValueKey('fas-mark-agility_speed_circuit')),
      '15,29',
    );
    await tester.pump();

    expect(find.text('20 pt'), findsNWidgets(4));
    expect(find.text('SUMA ORIENTATIVA'), findsOneWidget);
    expect(find.text('80 puntos'), findsOneWidget);
    expect(find.text('4/4 mínimos alcanzados'), findsOneWidget);
    expect(profile.saveCalls, 0);
  });

  testWidgets('no pide agilidad desde el día en que se cumplen 45 años', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FasPeriodicCalculatorPage(
          birthDateRepository: _BirthDateRepository(DateTime(1981, 9, 24)),
          repository: _Repository(),
          reference: reference,
          today: DateTime(2026, 9, 24),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('fas-mark-agility_speed_circuit')),
      findsNothing,
    );
    expect(
      find.text('Agilidad no exigible desde el día en que se cumplen 45 años.'),
      findsOneWidget,
    );
  });

  testWidgets('agrupa el resumen y las cuatro pruebas en dos columnas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: FasPeriodicCalculatorPage(
          birthDateRepository: _BirthDateRepository(DateTime(2001, 1, 1)),
          repository: _Repository(),
          reference: reference,
          today: DateTime(2027, 2, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(
      find.byKey(const ValueKey('fas-tests-grid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('fas-score-summary'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('fas-tests-grid'))).dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('guarda el test en el perfil sin preparación', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();

    await tester.pumpWidget(
      MaterialApp(
        home: FasPeriodicCalculatorPage(
          birthDateRepository: _BirthDateRepository(DateTime(2001, 1, 1)),
          repository: repository,
          reference: reference,
          today: DateTime(2027, 2, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final entry in {
      'upper_body_push_ups_2_min': '14',
      'abdominal_plank': '40',
      'run_2000_m': '1146',
      'agility_speed_circuit': '15,29',
    }.entries) {
      await tester.enterText(
        find.byKey(ValueKey('fas-mark-${entry.key}')),
        entry.value,
      );
    }
    await tester.pump();
    final save = find.text('Guardar test');
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.savedGoalId, isNull);
    expect(repository.savedAge, 26);
    expect(repository.savedAt, DateTime(2027, 2, 3));
    expect(
      find.text('Test guardado en tu historial personal.'),
      findsOneWidget,
    );
  });
}

class _Repository implements FasPeriodicAssessmentRepository {
  String? savedGoalId;
  int? savedAge;
  DateTime? savedAt;

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
    savedAt = completedAt;
    return 'saved';
  }
}

class _BirthDateRepository implements ProfileBirthDateRepository {
  _BirthDateRepository(this.value);

  DateTime? value;
  int saveCalls = 0;

  @override
  Future<DateTime?> get() async => value;

  @override
  Future<void> save(DateTime birthDate) async {
    saveCalls++;
    value = birthDate;
  }
}

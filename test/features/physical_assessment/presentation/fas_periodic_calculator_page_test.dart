import 'dart:async';

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

  for (final fails in [false, true]) {
    testWidgets(
      'permite calcular sin escribir cuando el perfil ${fails ? 'falla' : 'no tiene nacimiento'}',
      (tester) async {
        final profile = _BirthDateRepository(null)..fails = fails;
        final repository = _Repository();
        await _showCalculator(tester, reference, profile, repository);
        await _enterMarks(tester);

        expect(find.text('80 puntos'), findsOneWidget);
        expect(profile.saveCalls, 0);
        expect(repository.saveCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'sincroniza la edad escrita y el slider sin modificar el perfil',
    (tester) async {
      final profile = _BirthDateRepository(DateTime(2001, 1, 1));
      final repository = _Repository();
      await _showCalculator(tester, reference, profile, repository);

      await tester.enterText(
        find.byKey(const ValueKey('fas-calculation-age')),
        '42',
      );
      await tester.pump();
      final slider = find.byKey(const ValueKey('fas-age-slider'));
      expect(tester.widget<Slider>(slider).value, 42);

      await tester.drag(slider, const Offset(800, 0));
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(slider).value, 120);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('fas-calculation-age')),
            )
            .controller!
            .text,
        '120',
      );
      expect(profile.value, DateTime(2001, 1, 1));
      expect(profile.saveCalls, 0);
      expect(repository.saveCalls, 0);
    },
  );

  testWidgets('cancelar el guardado sin nacimiento permite seguir calculando', (
    tester,
  ) async {
    final profile = _BirthDateRepository(null);
    final repository = _Repository();
    await _showCalculator(tester, reference, profile, repository);
    await _enterMarks(tester);
    await tester.tap(find.text('Guardar test'));
    await tester.pumpAndSettle();

    expect(find.text('Guardar en tu historial'), findsOneWidget);
    expect(profile.saveCalls, 0);
    expect(repository.saveCalls, 0);
    await tester.tap(find.text('Seguir calculando'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('fas-calculation-age')),
      '42',
    );
    await tester.pump();
    expect(find.text('Guardar en tu historial'), findsNothing);
    expect(
      tester.widget<Slider>(find.byKey(const ValueKey('fas-age-slider'))).value,
      42,
    );
    expect(profile.saveCalls, 0);
    expect(repository.saveCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al pasar 44 a 45 y volver conserva agilidad y sus puntos', (
    tester,
  ) async {
    await _showCalculator(
      tester,
      reference,
      _BirthDateRepository(null),
      _Repository(),
    );
    final age = find.byKey(const ValueKey('fas-calculation-age'));
    final agility = find.byKey(
      const ValueKey('fas-mark-agility_speed_circuit'),
    );
    await tester.enterText(age, '44');
    await tester.pump();
    await _enterMarks(tester);
    final summary = find.byKey(const ValueKey('fas-score-summary'));
    final previousTotal = tester
        .widget<Text>(
          find
              .descendant(of: summary, matching: find.textContaining('puntos'))
              .first,
        )
        .data;

    await tester.enterText(age, '45');
    await tester.pump();
    expect(agility, findsNothing);
    expect(find.text('3/3 mínimos alcanzados'), findsOneWidget);
    expect(find.text(previousTotal!), findsNothing);

    await tester.enterText(age, '44');
    await tester.pump();
    expect(tester.widget<TextFormField>(agility).controller!.text, '15,29');
    expect(find.text(previousTotal), findsOneWidget);
    expect(find.text('4/4 mínimos alcanzados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recalcula con la edad del perfil antes de permitir guardar', (
    tester,
  ) async {
    final profile = _BirthDateRepository(DateTime(1982, 2, 3));
    final repository = _Repository();
    await _showCalculator(tester, reference, profile, repository);
    await tester.enterText(
      find.byKey(const ValueKey('fas-calculation-age')),
      '44',
    );
    await tester.pump();
    await _enterMarks(tester);
    await tester.tap(find.text('Guardar test'));
    await tester.pumpAndSettle();

    expect(find.text('Estás simulando otra edad'), findsOneWidget);
    expect(repository.saveCalls, 0);
    await tester.tap(find.text('Usar mi edad'));
    await tester.pumpAndSettle();
    expect(repository.saveCalls, 0);
    expect(
      find.byKey(const ValueKey('fas-mark-agility_speed_circuit')),
      findsNothing,
    );
    expect(
      tester.widget<Slider>(find.byKey(const ValueKey('fas-age-slider'))).value,
      45,
    );
    expect(find.text('3/3 mínimos alcanzados'), findsOneWidget);

    await tester.tap(find.text('Guardar test'));
    await tester.pumpAndSettle();
    expect(repository.saveCalls, 1);
    expect(repository.savedAge, 45);
    expect(repository.savedMarks, hasLength(3));
    expect(repository.savedMarks, isNot(contains('agility_speed_circuit')));
    expect(profile.saveCalls, 0);
  });

  testWidgets('la carga tardía del perfil respeta la edad elegida', (
    tester,
  ) async {
    final pendingBirthDate = Completer<DateTime?>();
    final profile = _BirthDateRepository(null)
      ..pending = pendingBirthDate.future;
    final repository = _Repository();
    await _showCalculator(tester, reference, profile, repository);
    await tester.enterText(
      find.byKey(const ValueKey('fas-calculation-age')),
      '42',
    );
    await tester.pump();
    pendingBirthDate.complete(DateTime(2001, 1, 1));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Slider>(find.byKey(const ValueKey('fas-age-slider'))).value,
      42,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('fas-calculation-age')))
          .controller!
          .text,
      '42',
    );
    expect(profile.saveCalls, 0);
    expect(repository.saveCalls, 0);
  });

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

    expect(find.textContaining('Referencia futura'), findsNothing);
    expect(find.text('Fuente y criterio oficial'), findsOneWidget);
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
      tester.getTopLeft(find.byKey(const ValueKey('fas-official-criteria'))).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('fas-assessment-context')))
            .dy,
      ),
    );
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
  int saveCalls = 0;
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
    saveCalls++;
    savedMarks = Map.of(marks);
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
  bool fails = false;
  Future<DateTime?>? pending;

  @override
  Future<DateTime?> get() async {
    if (fails) throw StateError('Perfil no disponible');
    return pending ?? Future.value(value);
  }

  @override
  Future<void> save(DateTime birthDate) async {
    saveCalls++;
    value = birthDate;
  }
}

Future<void> _showCalculator(
  WidgetTester tester,
  FasPeriodic2027Reference reference,
  _BirthDateRepository profile,
  _Repository repository,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: FasPeriodicCalculatorPage(
        birthDateRepository: profile,
        repository: repository,
        reference: reference,
        today: DateTime(2027, 2, 3),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterMarks(WidgetTester tester) async {
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
}

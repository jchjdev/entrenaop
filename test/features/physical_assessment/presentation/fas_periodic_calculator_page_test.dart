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
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final profile = _BirthDateRepository(DateTime(2001, 1, 1));

    await tester.pumpWidget(
      MaterialApp(
        home: FasPeriodicCalculatorPage(
          birthDateRepository: profile,
          reference: reference,
          today: DateTime(2026, 9, 24),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Referencia futura: este baremo de evaluación periódica entra en vigor el 01/01/2027.'), findsOneWidget);
    expect(find.text('H · hombres'), findsOneWidget);
    expect(find.text('M · mujeres'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Flexo-extensiones en 2 min'),
      '14',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Plancha isométrica'),
      '40',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Carrera 2.000 m'),
      '11:46',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Circuito de agilidad-velocidad'),
      '15,29',
    );
    await tester.tap(find.text('Calcular puntos'));
    await tester.pump();

    expect(find.text('20 puntos'), findsNWidgets(4));
    expect(
      find.text('Alcanza el mínimo general de 20 puntos por prueba'),
      findsOneWidget,
    );
    expect(
      find.textContaining('no define una suma o media total'),
      findsOneWidget,
    );
    expect(profile.saveCalls, 0);
  });

  testWidgets('no pide agilidad desde el día en que se cumplen 45 años', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FasPeriodicCalculatorPage(
          birthDateRepository: _BirthDateRepository(DateTime(1981, 9, 24)),
          reference: reference,
          today: DateTime(2026, 9, 24),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextFormField, 'Circuito de agilidad-velocidad'),
      findsNothing,
    );
    expect(
      find.text(
        'Agilidad no exigible desde el día en que se cumplen 45 años.',
      ),
      findsOneWidget,
    );
  });
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

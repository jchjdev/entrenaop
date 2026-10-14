import 'dart:async';

import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_calculator_page.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late FasPeriodic2027Reference reference;
  testWidgets(
    'la carga inicial lenta acaba en reintento y una respuesta vieja no reemplaza la nueva',
    (tester) async {
      final profile = _BirthDateRepository(DateTime(2001, 1, 1));
      final oldRequest = Completer<DateTime?>();
      profile.loader = () => oldRequest.future;
      await tester.pumpWidget(
        MaterialApp(
          home: FasPeriodicCalculatorPage(
            birthDateRepository: profile,
            repository: _Repository(),
            reference: reference,
            today: DateTime(2027, 2, 3),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 16));
      await tester.pump();
      expect(
        find.text('No se pudo cargar tu fecha de nacimiento'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      profile.loader = null;
      await tester.tap(find.text('No se pudo cargar tu fecha de nacimiento'));
      await tester.pumpAndSettle();
      final field = find.byKey(
        const ValueKey('fas-mark-upper_body_push_ups_2_min'),
      );
      await tester.enterText(field, '14');
      oldRequest.complete(DateTime(1980, 1, 1));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('fas-mark-agility_speed_circuit')),
        findsOneWidget,
      );
      expect(tester.widget<TextFormField>(field).controller!.text, '14');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('un error inmediato al abrir FAS permite volver a cargar', (
    tester,
  ) async {
    final profile = _BirthDateRepository(DateTime(2001, 1, 1))
      ..loader = () => Future.error(StateError('Sin conexión'));
    await tester.pumpWidget(
      MaterialApp(
        home: FasPeriodicCalculatorPage(
          birthDateRepository: profile,
          repository: _Repository(),
          reference: reference,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo cargar tu fecha de nacimiento'),
      findsOneWidget,
    );
    profile.loader = null;
    await tester.tap(find.text('No se pudo cargar tu fecha de nacimiento'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fas-mark-run_2000_m')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
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

  testWidgets('conserva el resumen y las cuatro tarjetas en dos columnas', (
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

    final first = tester.getTopLeft(
      find.ancestor(
        of: find.byKey(const ValueKey('fas-mark-upper_body_push_ups_2_min')),
        matching: find.byType(Card),
      ),
    );
    final second = tester.getTopLeft(
      find.ancestor(
        of: find.byKey(const ValueKey('fas-mark-abdominal_plank')),
        matching: find.byType(Card),
      ),
    );
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
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

  for (final viewport in [
    (width: 390.0, scale: 1.0),
    (width: 390.0, scale: 1.3),
    (width: 320.0, scale: 1.0),
    (width: 390.0, scale: 2.0),
    (width: 800.0, scale: 1.0),
  ]) {
    testWidgets(
      'los tiempos completos caben en ${viewport.width} px con texto ${viewport.scale}',
      (tester) async {
        tester.view.physicalSize = Size(viewport.width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: EntrenaTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(viewport.scale)),
              child: child!,
            ),
            home: FasPeriodicCalculatorPage(
              birthDateRepository: _BirthDateRepository(DateTime(2001, 1, 1)),
              repository: _Repository(),
              reference: reference,
              today: DateTime(2027, 2, 3),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final entry in {
          'upper_body_push_ups_2_min': '56',
          'abdominal_plank': '103',
          'run_2000_m': '626',
          'agility_speed_circuit': '15,250',
        }.entries) {
          final field = find.byKey(ValueKey('fas-mark-${entry.key}'));
          await tester.ensureVisible(field);
          await tester.enterText(field, entry.value);
          await tester.pumpAndSettle();
          final editable = tester.state<EditableTextState>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          );
          expect(editable.renderEditable.maxScrollExtent, 0);
          expect(tester.takeException(), isNull);
        }
        if (viewport.width >= 370 && viewport.scale < 1.6) {
          final first = find.ancestor(
            of: find.byKey(
              const ValueKey('fas-mark-upper_body_push_ups_2_min'),
            ),
            matching: find.byType(Card),
          );
          final second = find.ancestor(
            of: find.byKey(const ValueKey('fas-mark-abdominal_plank')),
            matching: find.byType(Card),
          );
          expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
          expect(
            tester.getTopLeft(second).dx,
            greaterThan(tester.getTopLeft(first).dx),
          );
        }
      },
    );
  }

  testWidgets('agilidad conserva el tiempo al escribir y corregir decimales', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: FasPeriodicCalculatorPage(
          birthDateRepository: _BirthDateRepository(DateTime(2001, 1, 1)),
          repository: _Repository(),
          reference: reference,
          today: DateTime(2027, 2, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('fas-mark-agility_speed_circuit'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    final controller = tester.widget<TextFormField>(field).controller!;
    for (final digit in '15,29'.split('')) {
      final text = '${controller.text}$digit';
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
      await tester.pump();
    }
    expect(controller.text, '15,29');
    final expectedPoints = reference
        .scoreFor(
          testId: 'agility_speed_circuit',
          category: AssessmentCategory.men,
          age: 26,
          mark: 15290,
        )!
        .points;
    expect(find.text('$expectedPoints pt'), findsOneWidget);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '15,39',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pump();
    expect(controller.selection.baseOffset, 4);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '15,359',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump();
    expect(controller.text, '15,359');
    expect(tester.takeException(), isNull);
  });

  testWidgets('volver al menú cierra el teclado numérico de la calculadora', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Menú principal')),
        ),
        GoRoute(
          path: '/calculator',
          builder: (_, _) => FasPeriodicCalculatorPage(
            birthDateRepository: _BirthDateRepository(DateTime(2001, 1, 1)),
            repository: _Repository(),
            reference: reference,
            today: DateTime(2027, 2, 3),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: EntrenaTheme.dark.copyWith(platform: TargetPlatform.iOS),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    router.push('/calculator');
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('fas-mark-agility_speed_circuit'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, '15,29');
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Menú principal'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
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
  Future<void> linkRecentToGoal({
    required String assessmentId,
    required String goalId,
  }) async {}

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
  Future<DateTime?> Function()? loader;

  @override
  Future<DateTime?> get() async => loader == null ? value : await loader!();

  @override
  Future<void> save(DateTime birthDate) async {
    saveCalls++;
    value = birthDate;
  }
}

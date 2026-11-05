import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/services/assessment_evaluator.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/evaluate_initial_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/domain/usecases/save_physical_assessment_usecase.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_calculator_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_assessment_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_history_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/initial_assessment_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/utils/preparation_measurement_history.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/builtin_assessment_fixtures.dart';

class LegacyTroop extends Fake implements PhysicalAssessmentRepository {}

class LegacyFas extends Fake implements FasPeriodicAssessmentRepository {
  @override
  Future<List<FasPeriodicAssessmentEntry>> history({String? goalId}) async =>
      [];
}

class BirthDate extends Fake implements ProfileBirthDateRepository {
  @override
  Future<DateTime?> get() async => DateTime(2001, 1, 1);
}

void main() {
  testWidgets('Tropa guarda la revisión abierta aunque se publique otra', (
    t,
  ) async {
    final references = MemoryBuiltinReferences(troopRevision());
    final cubit = PhysicalAssessmentCubit(
      evaluateInitialAssessment: const EvaluateInitialAssessmentUseCase(
        AssessmentEvaluator(),
      ),
      savePhysicalAssessment: SavePhysicalAssessmentUseCase(LegacyTroop()),
    );
    addTearDown(cubit.close);
    await t.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: InitialAssessmentPage(
            goalId: 'goal-1',
            references: references,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(references.loadedGoal, 'goal-1');
    final fields = find.byType(TextFormField);
    for (final (i, text) in [(0, '9'), (1, '100'), (2, '1100'), (3, '15,00')]) {
      await t.ensureVisible(fields.at(i));
      await t.enterText(fields.at(i), text);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    references.current = troopRevision(
      id: 'troop-2',
      version: 'troop-2',
      entryPushUps: 10,
    );
    await t.ensureVisible(find.text('Evaluar mis marcas'));
    await t.tap(find.text('Evaluar mis marcas'));
    await t.pumpAndSettle();
    expect(cubit.state.report!.catalogVersion, 'troop-catalog-1');
    await t.ensureVisible(find.text('Guardar en esta preparación'));
    await t.tap(find.text('Guardar en esta preparación'));
    await t.pumpAndSettle();
    expect(references.reads, 1);
    expect(references.records.single['revisionId'], 'troop-revision-1');
    expect(references.records.single['goalId'], 'goal-1');
    expect(references.records.single['marks']['agility_speed_circuit'], 15000);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'un fallo de catálogo Tropa no presenta mínimos locales y permite reintentar',
    (t) async {
      final references = MemoryBuiltinReferences(troopRevision())..fail = true;
      final cubit = PhysicalAssessmentCubit(
        evaluateInitialAssessment: const EvaluateInitialAssessmentUseCase(
          AssessmentEvaluator(),
        ),
        savePhysicalAssessment: SavePhysicalAssessmentUseCase(LegacyTroop()),
      );
      addTearDown(cubit.close);
      await t.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: InitialAssessmentPage(
              goalId: 'goal-1',
              references: references,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(
        find.text('No se pudo cargar el baremo de esta preparación.'),
        findsOneWidget,
      );
      references.fail = false;
      await t.tap(find.text('Reintentar cargar el baremo'));
      await t.pumpAndSettle();
      expect(references.reads, 2);
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(references.reads, 2);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'calculadora usa puntuación publicada y guarda su revisión sin preparación',
    (t) async {
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final first = (await t.runAsync(
        () => fasRevision(pointsFor14PushUps: 21),
      ))!;
      final next = (await t.runAsync(
        () =>
            fasRevision(id: 'fas-2', version: 'fas-2', pointsFor14PushUps: 22),
      ))!;
      final references = MemoryBuiltinReferences(first);
      await t.pumpWidget(
        MaterialApp(
          home: FasPeriodicCalculatorPage(
            birthDateRepository: BirthDate(),
            repository: LegacyFas(),
            references: references,
            today: DateTime(2026, 11, 5),
          ),
        ),
      );
      await t.pumpAndSettle();
      for (final (id, text) in [
        ('upper_body_push_ups_2_min', '14'),
        ('abdominal_plank', '40'),
        ('run_2000_m', '1146'),
        ('agility_speed_circuit', '16,29'),
      ]) {
        final field = find.byKey(ValueKey('fas-mark-$id'));
        await t.ensureVisible(field);
        await t.enterText(field, text);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      expect(find.text('21 pt'), findsOneWidget);
      references.current = next;
      await t.ensureVisible(find.text('Guardar test'));
      await t.tap(find.text('Guardar test'));
      await t.pumpAndSettle();
      expect(references.records.single['revisionId'], 'fas-revision-1');
      expect(references.records.single['goalId'], isNull);
      expect(references.records.single['age'], 25);
      expect(
        references.records.single['marks']['agility_speed_circuit'],
        16290,
      );
      expect(references.reads, 1);
      expect(t.takeException(), isNull);
    },
  );

  for (final changed in [false, true]) {
    testWidgets(
      'guardado FAS conserva las marcas y permite recuperar baremo cambiado: $changed',
      (t) async {
        t.view.physicalSize = const Size(800, 2400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final first = (await t.runAsync(
          () => fasRevision(pointsFor14PushUps: 21),
        ))!;
        final next = (await t.runAsync(
          () => fasRevision(
            id: 'fas-2',
            version: 'fas-2',
            pointsFor14PushUps: 22,
          ),
        ))!;
        final references = MemoryBuiltinReferences(first);
        await t.pumpWidget(
          MaterialApp(
            home: FasPeriodicCalculatorPage(
              birthDateRepository: BirthDate(),
              repository: LegacyFas(),
              references: references,
              today: DateTime(2026, 11, 5),
            ),
          ),
        );
        await t.pumpAndSettle();
        for (final (id, text) in [
          ('upper_body_push_ups_2_min', '14'),
          ('abdominal_plank', '40'),
          ('run_2000_m', '1146'),
          ('agility_speed_circuit', '16,29'),
        ]) {
          final field = find.byKey(ValueKey('fas-mark-$id'));
          await t.ensureVisible(field);
          await t.enterText(field, text);
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        final before = {
          for (final id in [
            'upper_body_push_ups_2_min',
            'abdominal_plank',
            'run_2000_m',
            'agility_speed_circuit',
          ])
            id: t
                .widget<TextFormField>(find.byKey(ValueKey('fas-mark-$id')))
                .controller!
                .text,
        };
        references.current = next;
        references.recordError = changed
            ? const PostgrestException(
                message: 'Recarga antes de guardar.',
                code: '22023',
                details: 'builtin_reference_changed',
              )
            : StateError('sin conexión');
        await t.ensureVisible(find.text('Guardar test'));
        await t.tap(find.text('Guardar test'));
        await t.pumpAndSettle();
        expect(references.records.single['revisionId'], 'fas-revision-1');
        expect(find.text('21 pt'), findsOneWidget);
        if (changed) {
          expect(find.text('Actualizar baremo'), findsOneWidget);
          expect(
            t
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Guardar test'),
                )
                .onPressed,
            isNull,
          );
          // Un fallo de actualización tampoco sustituye ni descarta las marcas.
          references.fail = true;
          await t.ensureVisible(find.text('Actualizar baremo'));
          await t.tap(find.text('Actualizar baremo'));
          await t.pumpAndSettle();
          expect(find.text('No se pudo cargar el baremo.'), findsOneWidget);
          references.fail = false;
          await t.tap(find.text('Reintentar cargar el baremo'));
          await t.pumpAndSettle();
          expect(find.text('22 pt'), findsOneWidget);
          expect(find.text('Actualizar baremo'), findsNothing);
          expect(references.reads, 3);
        } else {
          expect(find.text('No se pudo guardar el test.'), findsOneWidget);
          expect(find.text('Actualizar baremo'), findsNothing);
          expect(references.reads, 1);
        }
        for (final entry in before.entries) {
          expect(
            t
                .widget<TextFormField>(
                  find.byKey(ValueKey('fas-mark-${entry.key}')),
                )
                .controller!
                .text,
            entry.value,
          );
        }
        references.recordError = null;
        await t.ensureVisible(find.text('Guardar test'));
        await t.tap(find.text('Guardar test'));
        await t.pumpAndSettle();
        expect(
          references.records.last['revisionId'],
          changed ? 'fas-2' : 'fas-revision-1',
        );
        expect(references.records.last['age'], 25);
        expect(references.records.last['completedAt'], DateTime(2026, 11, 5));
        expect(
          references.records.last['marks']['agility_speed_circuit'],
          16290,
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('historial usa puntos guardados aunque haya otro baremo actual', (
    t,
  ) async {
    final reference = (await t.runAsync(fasRevision))!.asFas();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FasAssessmentHistoryCard(
            entry: _entry('attempt-1', 'scores-older', 21),
            reference: reference,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('21 puntos'), findsOneWidget);
    expect(find.textContaining('No se han podido consultar'), findsNothing);
    await t.tap(find.text('21 puntos'));
    await t.pumpAndSettle();
    expect(find.text('14 repeticiones'), findsOneWidget);
    expect(find.text('21 puntos'), findsNWidgets(2));
  });

  testWidgets(
    'FAS en preparación reintenta la carga y guarda su revisión fijada',
    (t) async {
      final initial = (await t.runAsync(fasRevision))!;
      final references = MemoryBuiltinReferences(initial)..fail = true;
      await t.pumpWidget(
        MaterialApp(
          home: FasPeriodicAssessmentPage(
            goalId: 'fas-goal',
            birthDateRepository: BirthDate(),
            repository: LegacyFas(),
            references: references,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('No se pudo cargar el baremo.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      references.fail = false;
      await t.tap(find.text('Reintentar cargar el baremo'));
      await t.pumpAndSettle();
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(4));
      expect(references.loadedGoal, 'fas-goal');
      for (final (i, text) in [
        (0, '14'),
        (1, '0040'),
        (2, '1146'),
        (3, '16,29'),
      ]) {
        await t.ensureVisible(fields.at(i));
        await t.enterText(fields.at(i), text);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      references.current = (await t.runAsync(
        () => fasRevision(id: 'next', version: 'next'),
      ))!;
      await t.ensureVisible(find.text('Guardar resultado del test'));
      await t.tap(find.text('Guardar resultado del test'));
      await t.pumpAndSettle();
      expect(references.records.single['revisionId'], 'fas-revision-1');
      expect(references.records.single['goalId'], 'fas-goal');
      expect(
        references.records.single['marks']['agility_speed_circuit'],
        16290,
      );
      expect(references.reads, 2);
      expect(t.takeException(), isNull);
    },
  );

  test(
    'comparación con snapshots separa dos versiones y usa dirección guardada',
    () {
      final series = preparationMeasurementHistory(
        fas: [
          _entry('older', 'scores-older', 20, day: 1),
          _entry('older-next', 'scores-older', 21, day: 2),
          _entry('new', 'scores-new', 25, day: 3),
        ],
      );
      expect(series, hasLength(2));
      final old = series.singleWhere((s) => s.version == 'scores-older');
      expect(old.canCompare, isTrue);
      expect(old.samples, hasLength(2));
      expect(
        series.singleWhere((s) => s.version == 'scores-new').canCompare,
        isFalse,
      );
    },
  );
}

FasPeriodicAssessmentEntry _entry(
  String id,
  String version,
  int points, {
  int day = 1,
}) => FasPeriodicAssessmentEntry(
  id: id,
  revisionId: 'revision-$version',
  goalId: null,
  scoringVersion: version,
  completedAt: DateTime(2026, 11, day),
  category: 'men',
  age: 25,
  isPreEffectiveReference: true,
  marks: [
    FasPeriodicAssessmentMark(
      testId: 'upper_body_push_ups_2_min',
      testName: 'Flexiones',
      unit: 'repetitions',
      value: 14,
      threshold: 14,
      meetsMinimum: true,
      points: points,
      scoredValue: 14,
      betterDirection: 'higher',
    ),
  ],
);

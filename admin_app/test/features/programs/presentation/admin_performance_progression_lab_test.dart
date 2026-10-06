import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_performance_progression_lab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';

import '../../../../../test/features/exercises/domain/strength_exercise_catalog_test.dart'
    show readCatalogJson;

void main() {
  Future<void> mount(WidgetTester tester, {bool profiles = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminPerformanceProgressionLab(
              key: UniqueKey(),
              repository: _Repository(profiles),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) => tap(tester, find.text('Continuar'));
  Future<void> example(WidgetTester tester) =>
      tap(tester, find.text('Cargar ejemplo completo'));
  Finder seriesField(String goal, int index) => find
      .descendant(
        of: find.byKey(ValueKey('targets_$goal')),
        matching: find.byType(TextFormField),
      )
      .at(index);
  String seriesValue(WidgetTester tester, String goal, int index) => tester
      .widget<EditableText>(
        find.descendant(
          of: seriesField(goal, index),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;
  Future<void> choose(WidgetTester tester, String key, String label) async {
    await tap(tester, find.byKey(ValueKey(key)));
    if (find.text(label).evaluate().isEmpty) {
      await tester.drag(find.byType(ListView).last, const Offset(0, 700));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text(label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> executionExamples(WidgetTester tester, String id) =>
      tap(tester, find.byKey(ValueKey('example_executions_$id')));

  Future<void> finish(WidgetTester tester) async {
    while (find.text('Continuar').evaluate().isNotEmpty) {
      await next(tester);
    }
    await tap(tester, find.text('Calcular propuestas'));
  }

  testWidgets('explica la referencia, el RIR y el dato real sin confundirlos', (
    tester,
  ) async {
    await mount(tester);
    await example(tester);
    await next(tester);
    expect(find.textContaining('dejando unas 3 más posibles'), findsOneWidget);
    await tap(
      tester,
      find.text('Cómo entender el margen de repeticiones (RIR)'),
    );
    expect(find.textContaining('sin descansar'), findsOneWidget);
    expect(
      find.textContaining('las 3 restantes no se realizan'),
      findsOneWidget,
    );
    expect(
      find.textContaining('aunque sea distinto del objetivo'),
      findsOneWidget,
    );
    expect(find.textContaining('debe quedar sin dato'), findsOneWidget);
    await next(tester);
    await next(tester);
    expect(
      find.textContaining('Esta referencia no utiliza RIR'),
      findsOneWidget,
    );
    expect(
      find.text('Cómo entender el margen de repeticiones (RIR)'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ejemplo recorre bloques y produce cuatro propuestas explícitas',
    (tester) async {
      await mount(tester);
      await example(tester);
      await next(tester);
      expect(find.textContaining('· Empujes'), findsOneWidget);
      expect(find.byKey(const ValueKey('targets_pull')), findsNothing);
      await finish(tester);
      expect(find.text('Objetivos con propuesta: 4/4'), findsOneWidget);
      expect(find.text('Dosis inicial · 8 / 8 repeticiones'), findsOneWidget);
      expect(find.text('Dosis inicial · 20 / 20 segundos'), findsOneWidget);
      expect(
        find.textContaining(
          'Coordinación, evolución por meses y publicación pendientes',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'volver conserva datos y dos respuestas buenas progresan una repetición',
    (tester) async {
      await mount(tester);
      await example(tester);
      await next(tester);
      await tester.enterText(seriesField('push', 0), '9');
      await executionExamples(tester, 'push');
      await next(tester);
      await tap(tester, find.text('Atrás'));
      expect(seriesValue(tester, 'push', 0), '9');
      expect(seriesValue(tester, 'push', 1), '8');
      await finish(tester);
      expect(find.text('Progresar · 9 / 9 repeticiones'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'banca consolidada aumenta carga y vuelve al inicio de horquilla',
    (tester) async {
      await mount(tester);
      await example(tester);
      for (final name in ['Flexiones', 'Dominadas', 'Plancha']) {
        await tap(tester, find.widgetWithText(FilterChip, name));
      }
      await next(tester);
      expect(
        find.textContaining('Paso 2 de 3 · Fuerza con carga'),
        findsOneWidget,
      );
      await tester.enterText(seriesField('bench', 0), '6');
      await tester.enterText(seriesField('bench', 1), '6');
      await executionExamples(tester, 'bench');
      await tap(tester, find.text('Calcular propuestas'));
      expect(
        find.text('Progresar · 4 / 4 repeticiones · 42.5 kg'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('isometría reduce segundos por dificultad sin usar RIR', (
    tester,
  ) async {
    await mount(tester);
    await example(tester);
    for (final name in ['Flexiones', 'Dominadas', 'Fuerza en banca']) {
      await tap(tester, find.widgetWithText(FilterChip, name));
    }
    await next(tester);
    await executionExamples(tester, 'plank');
    for (final index in [1, 2]) {
      await tap(tester, find.byTooltip('Editar registro $index de Plancha'));
      expect(find.byKey(const ValueKey('actual_rir_0')), findsNothing);
      await choose(tester, 'execution_tolerance', 'No, hubo dificultad');
      await tap(tester, find.text('Guardar registro'));
    }
    await tap(tester, find.text('Calcular propuestas'));
    expect(find.text('Reducir · 20 / 18 segundos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cuerda permanece pendiente junto a propuestas de otros objetivos',
    (tester) async {
      await mount(tester);
      await example(tester);
      await tap(tester, find.widgetWithText(FilterChip, 'Cuerda'));
      await finish(tester);
      expect(find.text('Objetivos con propuesta: 4/5'), findsOneWidget);
      expect(find.text('Dosificación pendiente'), findsOneWidget);
      expect(
        find.textContaining('El objetivo permanece visible'),
        findsOneWidget,
      );
    },
  );

  testWidgets('contexto y perfiles ausentes no producen una dosis', (
    tester,
  ) async {
    await mount(tester);
    await finish(tester);
    expect(find.text('Objetivos con propuesta: 0/4'), findsOneWidget);
    expect(find.text('Faltan datos o material'), findsNWidgets(4));
    await mount(tester, profiles: false);
    await example(tester);
    await finish(tester);
    expect(find.text('Objetivos con propuesta: 0/4'), findsOneWidget);
    expect(find.text('Dosificación pendiente'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('recorrido completo en pantalla estrecha sin desbordamientos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester);
    await example(tester);
    await finish(tester);
    expect(find.text('Objetivos con propuesta: 4/4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'entrada inválida se queda en el bloque y no avanza silenciosamente',
    (tester) async {
      await mount(tester);
      await example(tester);
      await next(tester);
      await tester.enterText(seriesField('push', 0), '0');
      await next(tester);
      expect(find.text('Introduce un entero entre 1 y 3600.'), findsOneWidget);
      expect(find.textContaining('· Empujes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('añadir y quitar una serie intermedia conserva las demás', (
    tester,
  ) async {
    await mount(tester);
    await example(tester);
    await next(tester);
    await tester.enterText(seriesField('push', 0), '7');
    await tester.enterText(seriesField('push', 1), '9');
    await tap(tester, find.text('Añadir serie'));
    expect(seriesValue(tester, 'push', 2), '9');
    await tester.enterText(seriesField('push', 2), '11');
    await tap(tester, find.byTooltip('Quitar serie 2'));
    expect(seriesValue(tester, 'push', 0), '7');
    expect(seriesValue(tester, 'push', 1), '11');
    await next(tester);
    await tap(tester, find.text('Atrás'));
    expect(seriesValue(tester, 'push', 1), '11');
    await finish(tester);
    expect(find.text('Dosis inicial · 7 / 11 repeticiones'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor limita filas y el ejemplo restablece las series', (
    tester,
  ) async {
    await mount(tester);
    await example(tester);
    await next(tester);
    await tap(tester, find.byTooltip('Quitar serie 2'));
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Quitar serie 1',
            ),
          )
          .onPressed,
      isNull,
    );
    for (var i = 0; i < 5; i++) {
      await tap(tester, find.text('Añadir serie'));
    }
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Añadir serie'))
          .onPressed,
      isNull,
    );
    await example(tester);
    await next(tester);
    expect(find.text('Dosis de trabajo · 2 series'), findsOneWidget);
    expect(seriesValue(tester, 'push', 0), '8');
    expect(seriesValue(tester, 'push', 1), '8');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editar la referencia conserva la dosis histórica del registro', (
    tester,
  ) async {
    await mount(tester);
    await example(tester);
    await next(tester);
    await executionExamples(tester, 'push');
    await tester.enterText(seriesField('push', 0), '10');
    await tap(tester, find.byTooltip('Editar registro 1 de Flexiones'));
    expect(find.textContaining('Pautado: 8 / 8 repeticiones'), findsOneWidget);
    await tap(tester, find.text('Cancelar'));
    await finish(tester);
    expect(find.text('Mantener · 10 / 8 repeticiones'), findsOneWidget);
    expect(
      find.textContaining('los registros conservan su dosis original'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('una interrupción por tiempo no se interpreta como dificultad', (
    tester,
  ) async {
    await mount(tester);
    await example(tester);
    await next(tester);
    await executionExamples(tester, 'push');
    for (final index in [1, 2]) {
      await tap(tester, find.byTooltip('Editar registro $index de Flexiones'));
      await tester.enterText(find.byKey(const ValueKey('actual_units_0')), '4');
      await choose(tester, 'execution_stop', 'Falta de tiempo');
      await tap(tester, find.text('Guardar registro'));
    }
    await finish(tester);
    expect(find.text('Mantener · 8 / 8 repeticiones'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('banca no progresa si las series se hicieron con menos kilos', (
    tester,
  ) async {
    await mount(tester);
    await example(tester);
    for (final name in ['Flexiones', 'Dominadas', 'Plancha']) {
      await tap(tester, find.widgetWithText(FilterChip, name));
    }
    await next(tester);
    await tester.enterText(seriesField('bench', 0), '6');
    await tester.enterText(seriesField('bench', 1), '6');
    await executionExamples(tester, 'bench');
    for (final index in [1, 2]) {
      await tap(
        tester,
        find.byTooltip('Editar registro $index de Fuerza en banca'),
      );
      await tester.enterText(find.byKey(const ValueKey('actual_load_0')), '35');
      await tester.enterText(find.byKey(const ValueKey('actual_load_1')), '35');
      await tap(tester, find.text('Guardar registro'));
    }
    await tap(tester, find.text('Calcular propuestas'));
    expect(
      find.text('Mantener · 6 / 6 repeticiones · 40.0 kg'),
      findsOneWidget,
    );
    expect(
      find.textContaining('La carga utilizada o la masa corporal faltan'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'RIR sin informar no se copia del objetivo ni permite progresar',
    (tester) async {
      await mount(tester);
      await example(tester);
      await next(tester);
      await executionExamples(tester, 'push');
      await tap(tester, find.byTooltip('Editar registro 1 de Flexiones'));
      await choose(tester, 'actual_rir_0', 'No sé estimarlo');
      await tap(tester, find.text('Guardar registro'));
      await tap(tester, find.byTooltip('Editar registro 1 de Flexiones'));
      expect(
        tester
            .widget<DropdownButtonFormField<double>>(
              find.byKey(const ValueKey('actual_rir_0')),
            )
            .initialValue,
        -1,
      );
      await tap(tester, find.text('Cancelar'));
      await finish(tester);
      expect(find.text('Mantener · 8 / 8 repeticiones'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Repository implements AdminExerciseRepository {
  _Repository(this.profiles);
  final bool profiles;
  @override
  Future<List<AdminCatalogExercise>> listOfficial() async => [
    for (final profile in StrengthExerciseCatalogCodec.decode(
      readCatalogJson(),
    ).exercises)
      AdminCatalogExercise(
        id: profile.code,
        name: profile.name,
        muscleGroups: const [],
        equipment: const [],
        difficulty: 'intermedio',
        exerciseType: 'repeticiones',
        trainingProfile: profiles ? profile : null,
      ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

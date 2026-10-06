import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_push_up_policy_lab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/strength_exercise_catalog_codec.dart';

import '../../../../../test/features/exercises/domain/strength_exercise_catalog_test.dart'
    show readCatalogJson;

void main() {
  Future<void> mount(
    WidgetTester tester, {
    bool profilesAvailable = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminPushUpPolicyLab(
              repository: _Repository(profilesAvailable: profilesAvailable),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> calculate(WidgetTester tester) =>
      tapVisible(tester, find.text('Calcular propuesta de prueba'));

  testWidgets('el ejemplo calcula y sustituye una configuración incompatible', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Repeticiones válidas de una serie de trabajo',
      ),
      '0',
    );
    await tapVisible(tester, find.text('La prueba tiene límite de tiempo'));
    await tapVisible(
      tester,
      find.widgetWithText(
        DropdownButtonFormField<double>,
        'RIR declarado en esa serie',
      ),
    );
    await tester.tap(find.text('9').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Cargar ejemplo y calcular'));

    expect(find.text('Propuesta para revisión'), findsOneWidget);
    expect(
      find.textContaining('Objetivos con propuesta para revisar: 1/1.'),
      findsOneWidget,
    );
    expect(find.textContaining('2 series × 8 repeticiones'), findsNWidgets(2));
    expect(
      tester
          .widget<DropdownButtonFormField<double>>(
            find.widgetWithText(
              DropdownButtonFormField<double>,
              'RIR declarado en esa serie',
            ),
          )
          .initialValue,
      3,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(
              SwitchListTile,
              'La prueba tiene límite de tiempo',
            ),
          )
          .value,
      isFalse,
    );
    expect(find.text('Este objetivo aún no está cubierto'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explica la falta de perfiles en la biblioteca recibida', (
    tester,
  ) async {
    await mount(tester, profilesAvailable: false);
    expect(
      find.textContaining('falta el perfil oficial de flexión estándar v1'),
      findsOneWidget,
    );
    expect(find.text('Reintentar catálogo'), findsOneWidget);
    expect(find.text('Cargar ejemplo y calcular'), findsNothing);
  });

  testWidgets('calcular con campos inválidos da un aviso visible', (
    tester,
  ) async {
    await mount(tester);
    await calculate(tester);
    expect(
      find.text('Revisa los campos señalados antes de calcular.'),
      findsOneWidget,
    );
    expect(find.text('Introduce una serie válida positiva.'), findsOneWidget);
    expect(find.text('Propuesta para revisión'), findsNothing);
  });

  testWidgets(
    'ADMIN revisa una propuesta individual con ejercicios reales del catálogo',
    (tester) async {
      await mount(tester);
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Repeticiones válidas de una serie de trabajo',
        ),
        '8',
      );
      await tapVisible(
        tester,
        find.widgetWithText(
          DropdownButtonFormField<double>,
          'RIR declarado en esa serie',
        ),
      );
      await tester.tap(find.text('3').last);
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.text('Capacidad y contexto actuales confirmados'),
      );
      await calculate(tester);
      expect(find.text('Propuesta para revisión'), findsOneWidget);
      expect(find.text('Lunes · Flexión estándar'), findsOneWidget);
      expect(find.text('Jueves · Flexión estándar'), findsOneWidget);
      expect(
        find.textContaining('2 series × 8 repeticiones'),
        findsNWidgets(2),
      );

      await tapVisible(
        tester,
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Respuesta simulada a la dosis anterior',
        ),
      );
      await tester.tap(find.text('Dos ejecuciones toleradas').last);
      await tester.pumpAndSettle();
      expect(find.text('Propuesta para revisión'), findsNothing);
      await calculate(tester);
      expect(
        find.textContaining('2 series × 9 repeticiones'),
        findsNWidgets(2),
      );
    },
  );

  testWidgets('no presenta cobertura para un protocolo cronometrado', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Repeticiones válidas de una serie de trabajo',
      ),
      '8',
    );
    await tapVisible(
      tester,
      find.text('Capacidad y contexto actuales confirmados'),
    );
    await tapVisible(tester, find.text('La prueba tiene límite de tiempo'));
    await calculate(tester);
    expect(find.text('Este objetivo aún no está cubierto'), findsOneWidget);
    expect(
      find.textContaining('Objetivos con propuesta para revisar: 0/1.'),
      findsOneWidget,
    );
    expect(find.textContaining('2 series ×'), findsNothing);
  });
}

class _Repository implements AdminExerciseRepository {
  _Repository({this.profilesAvailable = true});
  final bool profilesAvailable;
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
        trainingProfile: profilesAvailable ? profile : null,
      ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

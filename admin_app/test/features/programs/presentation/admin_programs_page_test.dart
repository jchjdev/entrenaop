import '../../../helpers/admin_test_app.dart';

import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_editor_page.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_programs_page.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_program_detail_page.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_program_scoring_editor.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_test_pass_standards_page.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_core/exercise_image.dart';

class _FakeExercises implements AdminExerciseRepository {
  @override
  Future<void> createOfficial(
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
  }) async {}

  @override
  Future<List<AdminCatalogExercise>> listOfficial() async => const [];

  @override
  Future<void> updateOfficial(
    String id,
    ExerciseDraft draft, {
    ExerciseImageUpload? image,
    bool removeImage = false,
  }) async {}
}

class _FakeRepository implements AdminProgramRepository {
  @override
  Future<AdminPerformanceSetup> loadPerformanceSetup(String programId) async =>
      const AdminPerformanceSetup([], []);
  @override
  Future<void> savePerformanceStrategy(
    String testId,
    Map<String, dynamic>? strategy,
  ) async {}
  _FakeRepository({required this.allowed});

  final bool allowed;
  int listCalls = 0;
  int createCalls = 0;
  bool failCreate = false;
  final programs = <AdminProgram>[];
  final tests = <AdminProgramTest>[];
  final modules = <AdminProgramTrainingModule>[];
  AdminProgramScoringRule? scoringRule;
  final bands = <AdminScoreBand>[];
  final standards = <AdminPassStandard>[];
  final issues = <String>[];

  @override
  Future<bool> hasAccess() async => allowed;

  @override
  Future<List<AdminProgram>> listPrograms() async {
    listCalls++;
    return List.of(programs);
  }

  @override
  Future<void> createDraft({required String name, required String kind}) async {
    createCalls++;
    if (failCreate) throw StateError('Sin conexión');
    programs.add(
      AdminProgram(id: 'new', name: name, kind: kind, enabled: false),
    );
  }

  @override
  Future<List<String>> assessmentIssues(String programId) async =>
      List.of(issues);

  @override
  Future<void> publishAssessment(String programId) async {
    final index = programs.indexWhere((item) => item.id == programId);
    final current = programs[index];
    programs[index] = AdminProgram(
      id: current.id,
      name: current.name,
      kind: current.kind,
      enabled: true,
    );
  }

  @override
  Future<void> cloneAssessmentVersion(
    String programId,
    String name,
    String version,
  ) async {}

  @override
  Future<List<AdminProgramTest>> listTests(String programId) async =>
      List.of(tests);

  @override
  Future<void> createTest(String programId, AdminProgramTest test) async {
    tests.add(test);
  }

  @override
  Future<void> updateTest(
    AdminProgramTest test, {
    bool resetBands = false,
  }) async {
    final index = tests.indexWhere((item) => item.id == test.id);
    tests[index] = test;
    if (resetBands) {
      bands.clear();
      standards.clear();
    }
  }

  @override
  Future<void> deleteTest(String testId) async {
    tests.removeWhere((test) => test.id == testId);
    modules.removeWhere((module) => module.testId == testId);
    bands.clear();
    standards.clear();
  }

  @override
  Future<List<AdminProgramTrainingModule>> listTrainingModules(
    String programId,
  ) async => List.of(modules);

  @override
  Future<void> setRunningTwoKilometreModule(
    String testId, {
    required bool enabled,
  }) async {
    modules.removeWhere((module) => module.testId == testId);
    if (enabled) {
      modules.add(
        AdminProgramTrainingModule(
          testId: testId,
          moduleKey: 'running_2000m_v1',
        ),
      );
    }
  }

  @override
  Future<AdminProgramScoringRule?> getScoringRule(String programId) async =>
      scoringRule;

  @override
  Future<void> saveScoringRule(
    String programId,
    AdminProgramScoringRule rule,
  ) async => scoringRule = rule;

  @override
  Future<List<AdminScoreBand>> listScoreBands(String testId) async =>
      List.of(bands);

  @override
  Future<void> addScoreBand(String testId, AdminScoreBand band) async {
    bands.add(band);
  }

  @override
  Future<void> updateScoreBand(String testId, AdminScoreBand band) async {
    final index = bands.indexWhere((item) => item.id == band.id);
    bands[index] = band;
  }

  @override
  Future<void> deleteScoreBand(String bandId) async {
    bands.removeWhere((band) => band.id == bandId);
  }

  @override
  Future<void> importScoreBands(
    String testId,
    List<AdminScoreBand> rows, {
    required bool replace,
  }) async {
    if (replace) bands.clear();
    bands.addAll(rows);
  }

  @override
  Future<List<AdminPassStandard>> listPassStandards(String testId) async =>
      List.of(standards);

  @override
  Future<void> savePassStandard(
    String testId,
    AdminPassStandard standard,
  ) async {
    final index = standards.indexWhere((item) => item.id == standard.id);
    if (index < 0) {
      standards.add(standard);
    } else {
      standards[index] = standard;
    }
  }

  @override
  Future<void> deletePassStandard(String standardId) async =>
      standards.removeWhere((item) => item.id == standardId);

  @override
  Future<AdminContextualResult> previewContextualAttempt(
    String programId,
    String category,
    DateTime birthDate,
    DateTime assessedOn,
    DateTime? referenceOn,
    List<AdminAttemptMark> marks,
  ) async => AdminContextualResult(
    passed: true,
    age: assessedOn.year - birthDate.year,
    mode: scoringRule?.scoringMode ?? 'points',
    total: scoringRule?.scoringMode == 'pass_fail' ? null : 6,
    details: const [],
  );

  @override
  Future<AdminAttemptPreview> previewAttempt(
    String programId,
    String category,
    List<AdminAttemptMark> marks,
  ) async => const AdminAttemptPreview(
    total: 6,
    passed: true,
    eachPassed: true,
    version: 'test_v1',
    details: [],
  );
}

class _FakeWorkouts implements AdminWorkoutRepository {
  @override
  Future<WorkoutTemplate?> getTemplateById(String templateId) async => null;

  @override
  Future<void> publishDraft(String templateId) async {}

  @override
  Future<void> remove(String templateId) async {}

  @override
  Future<String> revise(
    String templateId,
    CreatePersonalWorkoutInput input,
  ) async => 'revised-id';

  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async => const [];

  @override
  Future<String> createDraft(String? programId, dynamic input) async => 'draft';

  @override
  Future<List<AdminExercise>> listPublicExercises() async => const [];

  @override
  Future<List<AdminWorkoutSummary>> listForProgram(String programId) async =>
      const [];
}

void main() {
  testWidgets('perder la sesión retira un editor incluso con cambios pendientes', (tester) async {
    final session = ValueNotifier<bool>(true);
    final router = createAdminRouter(
      programs: _FakeRepository(allowed: true), workouts: _FakeWorkouts(), exercises: _FakeExercises(),
      onSignOut: () {}, initialLocation: '/sessions/new',
      authChanges: session, isAuthenticated: () => session.value,
      loginBuilder: (_) => const Scaffold(body: Text('Acceso al admin')),
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(AdminWorkoutEditorPage), findsOneWidget);
    final name = find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'Nombre de la sesión');
    await tester.enterText(name, 'Privado de la cuenta anterior');
    session.value = false;
    await tester.pumpAndSettle();
    expect(find.text('Acceso al admin'), findsOneWidget);
    expect(find.byType(AdminWorkoutEditorPage), findsNothing);
    expect(find.text('¿Salir sin guardar?'), findsNothing);
  });
  testWidgets('una URL de editor no evita el control de acceso del admin', (
    tester,
  ) async {
    final repository = _FakeRepository(allowed: false);
    final router = createAdminRouter(
      programs: repository,
      workouts: _FakeWorkouts(),
      exercises: _FakeExercises(),
      onSignOut: () {},
      initialLocation: '/sessions/new',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(AdminWorkoutEditorPage), findsNothing);
    expect(find.textContaining('no tiene permiso'), findsWidgets);
    expect(repository.listCalls, 0);
  });

  testWidgets(
    'un detalle se reconstruye por URL y un identificador inexistente ofrece salida',
    (tester) async {
      final repository = _FakeRepository(allowed: true)
        ..programs.add(
          const AdminProgram(
            id: 'direct',
            name: 'Acceso directo',
            kind: 'access',
            enabled: false,
          ),
        );
      final router = createAdminRouter(
        programs: repository,
        workouts: _FakeWorkouts(),
        exercises: _FakeExercises(),
        onSignOut: () {},
        initialLocation: '/programs/direct',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byType(AdminProgramDetailPage), findsOneWidget);
      router.go('/programs/missing');
      await tester.pumpAndSettle();
      expect(find.textContaining('no está disponible'), findsOneWidget);
      await tester.tap(find.text('Ir a programas'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminProgramsPage), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/programs');
    },
  );

  testWidgets('la búsqueda de programas combina términos e ignora tildes', (
    tester,
  ) async {
    final repository = _FakeRepository(allowed: true)
      ..programs.addAll(const [
        AdminProgram(
          id: 'police',
          name: 'Policía Nacional',
          kind: 'access',
          enabled: false,
        ),
        AdminProgram(
          id: 'fas',
          name: 'Evaluación FAS',
          kind: 'internal_assessment',
          enabled: true,
        ),
      ]);
    await tester.pumpWidget(
      AdminTestApp(
        home: AdminProgramsPage(
          repository: repository,
          workoutRepository: _FakeWorkouts(),
          exerciseRepository: _FakeExercises(),
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final search = find.widgetWithText(TextField, 'Buscar programas');
    await tester.scrollUntilVisible(
      search,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(search, 'policia borrador');
    await tester.pumpAndSettle();
    expect(find.text('Policía Nacional'), findsOneWidget);
    expect(find.text('Evaluación FAS'), findsNothing);
    await tester.enterText(search, 'algo inexistente');
    await tester.pumpAndSettle();
    expect(find.text('No hay programas con esa búsqueda.'), findsOneWidget);
  });
  for (final width in [360.0, 1100.0]) {
    testWidgets('panel de administración adaptable a ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repository = _FakeRepository(allowed: true);
      repository.programs.add(
        const AdminProgram(
          id: 'program',
          name: 'Preparación con nombre largo para revisar la disposición',
          kind: 'access',
          enabled: false,
        ),
      );
      var signedOut = false;
      await tester.pumpWidget(
        AdminTestApp(
          theme: EntrenaTheme.dark,
          home: AdminProgramsPage(
            repository: repository,
            workoutRepository: _FakeWorkouts(),
            exerciseRepository: _FakeExercises(),
            onSignOut: () => signedOut = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EntrenaWordmark), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Borrador'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Cerrar sesión'));
      expect(signedOut, isTrue);
    });
  }

  test('tabla pegada respeta columna, edad, decimal y extremo abierto', () {
    const exercise = AdminProgramTest(
      code: 'run',
      name: 'Carrera',
      unit: 'seconds',
      betterDirection: 'lower',
      protocolNotes: 'Carrera sobre pista oficial.',
      definitionVersion: 1,
      markStep: 0.1,
      minAge: 18,
      maxAge: 60,
    );
    final rows = parseScoreBandsTable(
      'H;18;34;0;8,2;10\nM;35;60;8,3;*;0',
      exercise,
    );
    expect(rows, hasLength(2));
    expect(rows.first.category, 'men');
    expect(rows.first.maxMark, 8.2);
    expect(rows.last.category, 'women');
    expect(rows.last.maxMark, isNull);
    expect(
      () => parseScoreBandsTable('H;61;70;0;8;10', exercise),
      throwsFormatException,
    );
  });
  testWidgets('sin permiso no consulta ni muestra borradores', (tester) async {
    final repository = _FakeRepository(allowed: false);
    await tester.pumpWidget(
      AdminTestApp(
        home: AdminProgramsPage(
          repository: repository,
          workoutRepository: _FakeWorkouts(),
          exerciseRepository: _FakeExercises(),
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('no tiene permiso'), findsOneWidget);
    expect(find.text('Nuevo programa'), findsNothing);
    expect(repository.listCalls, 0);
  });

  testWidgets('administración crea un borrador y vuelve a listarlo', (
    tester,
  ) async {
    final repository = _FakeRepository(allowed: true);
    await tester.pumpWidget(
      AdminTestApp(
        home: AdminProgramsPage(
          repository: repository,
          workoutRepository: _FakeWorkouts(),
          exerciseRepository: _FakeExercises(),
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Programas'), findsOneWidget);
    expect(find.text('Sesiones oficiales'), findsOneWidget);
    expect(find.text('Ejercicios oficiales'), findsOneWidget);

    await tester.tap(find.text('Crear programa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Guardia Civil');
    repository.failCreate = true;
    await tester.tap(find.text('Crear borrador'));
    await tester.pumpAndSettle();
    expect(repository.programs, isEmpty);
    expect(find.textContaining('Tus datos siguen aquí'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'Guardia Civil',
    );
    repository.failCreate = false;
    await tester.tap(find.text('Crear borrador'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 2);
    expect(repository.programs.single.kind, 'access');
    expect(repository.programs.single.enabled, false);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Guardia Civil'), findsOneWidget);
    expect(find.text('Borrador'), findsOneWidget);
    expect(repository.listCalls, 2);
  });

  testWidgets('un programa borrador incorpora su prueba con protocolo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeRepository(allowed: true)
      ..programs.add(
        const AdminProgram(
          id: 'cnp',
          name: 'CNP',
          kind: 'access',
          enabled: false,
        ),
      );
    await tester.pumpWidget(
      AdminTestApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: AdminProgramsPage(
          repository: repository,
          workoutRepository: _FakeWorkouts(),
          exerciseRepository: _FakeExercises(),
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('CNP'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('CNP'));
    await tester.pumpAndSettle();
    expect(find.text('Pruebas del programa'), findsOneWidget);
    await tester.tap(find.text('Añadir prueba'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Carrera 1.000 m');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Recorrer 1.000 metros en pista según la convocatoria.',
    );
    await tester.ensureVisible(find.text('Repeticiones').last);
    await tester.tap(find.text('Repeticiones').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiempo en segundos').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Marca más alta').last);
    await tester.tap(find.text('Marca más alta').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marca más baja').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar prueba'));
    await tester.pumpAndSettle();
    expect(repository.tests.single.code, 'carrera_1_000_m');
    expect(repository.tests.single.unit, 'seconds');
    expect(repository.tests.single.betterDirection, 'lower');
    expect(repository.tests.single.category, 'both');
    expect(repository.tests.single.groupCode, 'exercise_1');
    expect(find.text('Carrera 1.000 m'), findsOneWidget);
    expect(find.text('Prueba añadida al borrador.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.text('Carrera 1.000 m'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Editar prueba'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar prueba'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Carrera 1.000 metros',
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(repository.tests.single.name, 'Carrera 1.000 metros');
    await tester.pump(const Duration(seconds: 5));

    await tester.scrollUntilVisible(
      find.text('Borrar prueba'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Borrar prueba'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar prueba').last);
    await tester.pumpAndSettle();
    expect(repository.tests, isEmpty);
  });

  testWidgets('ADMIN vincula solo la prueba de 2 km compatible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeRepository(allowed: true)
      ..tests.addAll(const [
        AdminProgramTest(
          id: '1000',
          code: 'run1000',
          name: 'Carrera 1.000 m',
          unit: 'seconds',
          betterDirection: 'lower',
          protocolNotes: 'Carrera cronometrada.',
          definitionVersion: 1,
          distanceMeters: 1000,
        ),
        AdminProgramTest(
          id: '2000',
          code: 'run2000',
          name: 'Carrera 2.000 m',
          unit: 'seconds',
          betterDirection: 'lower',
          protocolNotes: 'Carrera continua cronometrada.',
          definitionVersion: 1,
          distanceMeters: 2000,
          measurementProtocol: 'run_2000m_v1',
        ),
      ]);
    await tester.pumpWidget(
      AdminTestApp(
        home: AdminProgramDetailPage(
          program: const AdminProgram(
            id: 'draft',
            name: 'Borrador',
            kind: 'access',
            enabled: false,
          ),
          repository: repository,
          workoutRepository: _FakeWorkouts(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Módulos de entrenamiento'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Prueba cronometrada de 2.000 m'));
    await tester.tap(find.text('Prueba cronometrada de 2.000 m'));
    await tester.pumpAndSettle();
    expect(find.text('Carrera 2.000 m').last, findsOneWidget);
    expect(find.text('Carrera 1.000 m').last, findsOneWidget);
    await tester.tap(find.text('Carrera 2.000 m').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vincular carrera 2 km'));
    await tester.pumpAndSettle();
    expect(repository.modules.single.testId, '2000');
  });

  testWidgets('baremo H/M y simulación muestran el ejercicio correspondiente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeRepository(allowed: true)
      ..programs.add(
        const AdminProgram(
          id: 'cnp',
          name: 'Policía Nacional',
          kind: 'access',
          enabled: false,
        ),
      )
      ..tests.addAll(const [
        AdminProgramTest(
          id: 'h',
          code: 'dominadas_h',
          name: 'Dominadas',
          unit: 'repetitions',
          betterDirection: 'higher',
          protocolNotes: 'Dominadas estrictas del anexo II.',
          definitionVersion: 1,
          category: 'men',
          groupCode: 'barra',
          displayOrder: 2,
        ),
        AdminProgramTest(
          id: 'm',
          code: 'suspension_m',
          name: 'Suspensión en barra',
          unit: 'seconds',
          betterDirection: 'higher',
          protocolNotes: 'Suspensión estática del anexo II.',
          definitionVersion: 1,
          category: 'women',
          groupCode: 'barra',
          displayOrder: 2,
        ),
      ])
      ..bands.addAll(const [
        AdminScoreBand(
          id: 'one',
          category: 'men',
          minMark: 5,
          maxMark: 5,
          points: 1,
        ),
        AdminScoreBand(id: 'ten', category: 'men', minMark: 17, points: 10),
      ]);
    await tester.pumpWidget(
      AdminTestApp(
        home: AdminProgramsPage(
          repository: repository,
          workoutRepository: _FakeWorkouts(),
          exerciseRepository: _FakeExercises(),
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Policía Nacional'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Policía Nacional'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Definir calificación'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Versión del baremo'),
      'boe_cnp_2026_v1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fuente oficial'),
      'BOE-A-2026-15055, anexo II',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enlace oficial'),
      'https://www.boe.es/buscar/doc.php?id=BOE-A-2026-15055',
    );
    await tester.ensureVisible(find.text('Guardar regla'));
    await tester.tap(find.text('Guardar regla'));
    await tester.pumpAndSettle();
    expect(repository.scoringRule?.aggregation, 'average');
    expect(repository.scoringRule?.minEachPoints, 1);
    expect(repository.scoringRule?.minAggregatePoints, 5);
    expect(find.text('Dominadas'), findsOneWidget);
    expect(find.text('Suspensión en barra'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.text('Dominadas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Editar baremo de la prueba'));
    await tester.tap(find.text('Editar baremo de la prueba'));
    await tester.pumpAndSettle();
    expect(find.textContaining('mínimo para puntuar: 5'), findsOneWidget);
    expect(find.textContaining('marca para 10 puntos: 17'), findsOneWidget);
    await tester.tap(find.byTooltip('Editar tramo').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Desde (vacío = sin mínimo)'),
      '6',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hasta (vacío = sin máximo)'),
      '6',
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(repository.bands.first.minMark, 6);
    expect(find.textContaining('mínimo para puntuar: 6'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simular calificación'));
    await tester.pumpAndSettle();
    expect(find.text('Dominadas'), findsNothing);
    await tester.tap(find.textContaining('Nacimiento:'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baremo M'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Suspensión en barra'), findsOneWidget);
    expect(find.textContaining('Dominadas'), findsNothing);
    await tester.enterText(find.byType(TextFormField), '95');
    await tester.tap(find.text('Evaluar marcas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('6 puntos'), findsOneWidget);
  });

  testWidgets('ADMIN crea, edita y borra mínimos por sexo y edad', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeRepository(allowed: true);
    const test = AdminProgramTest(
      id: 'run',
      code: 'run',
      name: 'Carrera',
      unit: 'seconds',
      betterDirection: 'lower',
      protocolNotes: 'Recorrer la distancia oficial.',
      definitionVersion: 1,
      minAge: 18,
      maxAge: 60,
    );
    await tester.pumpWidget(
      AdminTestApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE65100),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: AdminTestPassStandardsPage(
          test: test,
          repository: repository,
          editable: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir mínimo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Edad desde'),
      '35',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Edad hasta'),
      '39',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Marca máxima para aprobar'),
      '320',
    );
    await tester.tap(find.text('Guardar mínimo'));
    await tester.pumpAndSettle();
    expect(repository.standards.single.minAge, 35);
    expect(repository.standards.single.maxAge, 39);
    expect(repository.standards.single.threshold, 320);
    expect(find.textContaining('35–39 años'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar mínimo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Marca máxima para aprobar'),
      '310',
    );
    await tester.tap(find.text('Guardar mínimo'));
    await tester.pumpAndSettle();
    expect(repository.standards.single.threshold, 310);

    await tester.tap(find.byTooltip('Borrar mínimo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar').last);
    await tester.pumpAndSettle();
    expect(repository.standards, isEmpty);
  });

  testWidgets('publicar bloquea baremos incompletos y actualiza el catálogo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeRepository(allowed: true)
      ..programs.add(
        const AdminProgram(
          id: 'p',
          name: 'Programa libre',
          kind: 'access',
          enabled: false,
        ),
      )
      ..issues.add('Falta un mínimo para mujeres de 35 años.');
    await tester.pumpWidget(
      AdminTestApp(
        home: AdminProgramsPage(
          repository: repository,
          workoutRepository: _FakeWorkouts(),
          exerciseRepository: _FakeExercises(),
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Programa libre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar y publicar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Falta un mínimo'), findsOneWidget);
    expect(repository.programs.single.enabled, false);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    repository.issues.clear();
    await tester.tap(find.text('Revisar y publicar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar').last);
    await tester.pumpAndSettle();
    expect(repository.programs.single.enabled, true);
    expect(find.text('Publicado'), findsOneWidget);
  });
}

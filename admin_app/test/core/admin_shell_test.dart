import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/exercises/presentation/admin_exercises_page.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_pages.dart';
import 'package:entrenaop_admin/features/pro_access/data/admin_pro_access_repository.dart';
import 'package:entrenaop_admin/features/pro_access/presentation/admin_pro_access_page.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_performance_progression_lab.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_programs_page.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_push_up_policy_lab.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_program_workouts_page.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';

class _Programs extends Fake implements AdminProgramRepository {
  bool allowed = true;
  int reads = 0;
  @override
  Future<bool> hasAccess() async => allowed;
  @override
  Future<List<AdminProgram>> listPrograms() async {
    reads++;
    return const [
      AdminProgram(
        id: 'police',
        name: 'Policía Nacional · Acceso',
        kind: 'access',
        enabled: false,
      ),
      AdminProgram(
        id: 'fas',
        name: 'Evaluación física FAS',
        kind: 'internal_assessment',
        enabled: true,
      ),
    ];
  }
}

class _Workouts extends Fake implements AdminWorkoutRepository {
  int reads = 0;
  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async {
    reads++;
    return const [];
  }

  @override
  Future<List<AdminExercise>> listPublicExercises() async => [];
}

class _Exercises extends Fake implements AdminExerciseRepository {
  int reads = 0;
  @override
  Future<List<AdminCatalogExercise>> listOfficial() async {
    reads++;
    return [];
  }
}

class _Guided extends Fake implements AdminGuidedRepository {
  int programReads = 0, warmupReads = 0;
  @override
  Future<List<GuidedProgram>> programs() async {
    programReads++;
    return [];
  }

  @override
  Future<List<GuidedWarmup>> warmups() async {
    warmupReads++;
    return [];
  }
}

class _Accounts extends Fake implements AdminProAccessRepository {
  bool allowed = true, fail = false;
  int reads = 0;
  @override
  Future<bool> canManageAccounts() async {
    if (fail) throw StateError('Sin conexión');
    return allowed;
  }

  @override
  Future<AdminAccountDirectory> list({
    String search = '',
    String? afterId,
  }) async {
    reads++;
    return const AdminAccountDirectory([]);
  }
}

class _Fixture {
  final programs = _Programs();
  final workouts = _Workouts();
  final exercises = _Exercises();
  final guided = _Guided();
  final accounts = _Accounts();

  GoRouter router({String path = '/programs', bool authenticated = true}) =>
      createAdminRouter(
        programs: programs,
        workouts: workouts,
        exercises: exercises,
        guided: guided,
        proAccess: accounts,
        onSignOut: () {},
        initialLocation: path,
        isAuthenticated: () => authenticated,
        loginBuilder: (_) => const Scaffold(body: Text('Acceso al admin')),
      );
}

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<GoRouter> _mount(
  WidgetTester tester,
  _Fixture fixture, {
  String path = '/programs',
  bool authenticated = true,
  double textScale = 1,
  ProfessionalThemeController? appearance,
}) async {
  final theme =
      appearance ??
      ProfessionalThemeController(read: () => 'dark', write: (_) {});
  if (appearance == null) addTearDown(theme.dispose);
  final router = fixture.router(path: path, authenticated: authenticated);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('admin-review'),
      child: ProfessionalThemeScope(
        controller: theme,
        child: Builder(
          builder: (context) => MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: EntrenaTheme.light,
            darkTheme: EntrenaTheme.dark,
            themeMode: ProfessionalThemeScope.maybeOf(context)!.value,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder _nav(String path) => find.byKey(ValueKey('admin-nav-$path'));

Future<void> _select(WidgetTester tester, String path) async {
  await tester.ensureVisible(_nav(path));
  await tester.tap(_nav(path));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el selector de ADMIN cambia el tema y lo conserva al navegar', (
    t,
  ) async {
    _size(t, const Size(1440, 1000));
    final theme = ProfessionalThemeController(
      read: () => 'dark',
      write: (_) {},
    );
    addTearDown(theme.dispose);
    final router = await _mount(t, _Fixture(), appearance: theme);
    await t.tap(find.byTooltip('Cambiar a modo claro'));
    await t.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/programs');
    expect(
      Theme.of(t.element(find.byType(AdminProgramsPage))).brightness,
      Brightness.light,
    );
    await _select(t, '/sessions');
    expect(
      Theme.of(t.element(find.byType(AdminProgramWorkoutsPage))).brightness,
      Brightness.light,
    );
    await t.tap(find.byTooltip('Cambiar a modo oscuro'));
    await t.pumpAndSettle();
    expect(
      Theme.of(t.element(find.byType(AdminProgramWorkoutsPage))).brightness,
      Brightness.dark,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'el menú conecta todos los catálogos y ambos laboratorios con las rutas reales',
    (tester) async {
      _size(tester, const Size(1440, 1000));
      final fixture = _Fixture();
      final router = await _mount(tester, fixture);
      expect(find.text('Contenido'), findsOneWidget);
      expect(find.text('Preparación deportiva'), findsOneWidget);
      expect(find.text('Gestión'), findsOneWidget);
      expect(find.text('Herramientas'), findsOneWidget);
      expect(find.text('¿Qué quieres gestionar?'), findsNothing);
      expect(tester.widget<ListTile>(_nav('/programs')).selected, isTrue);

      await _select(tester, '/guided-programs');
      expect(find.byType(AdminGuidedCatalogPage), findsOneWidget);
      expect(fixture.guided.programReads, 1);
      await _select(tester, '/sessions');
      expect(find.byType(AdminProgramWorkoutsPage), findsOneWidget);
      expect(fixture.workouts.reads, 1);
      await _select(tester, '/warmups');
      expect(fixture.guided.warmupReads, 1);
      await _select(tester, '/exercises');
      expect(find.byType(AdminExercisesPage), findsOneWidget);
      expect(fixture.exercises.reads, 1);
      await _select(tester, '/accounts');
      expect(find.byType(AdminProAccessPage), findsOneWidget);
      expect(fixture.accounts.reads, 1);
      await _select(tester, '/laboratory');
      expect(find.byType(AdminPerformanceProgressionLab), findsOneWidget);
      await tester.tap(find.text('Política de flexiones'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminPushUpPolicyLab), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/laboratory/push-ups',
      );
      expect(tester.widget<ListTile>(_nav('/laboratory')).selected, isTrue);
      expect(fixture.programs.reads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cambiar de sección respeta el borrador y permite cancelar la salida',
    (tester) async {
      _size(tester, const Size(1440, 1000));
      final router = await _mount(tester, _Fixture(), path: '/sessions/new');
      expect(find.byTooltip('Cerrar sesión'), findsNothing);
      expect(tester.widget<ListTile>(_nav('/sessions')).selected, isTrue);
      final name = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Nombre de la sesión',
      );
      await tester.enterText(name, 'Borrador que debe conservarse');
      await _select(tester, '/exercises');
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/sessions/new');
      expect(find.byType(AdminWorkoutEditorPage), findsOneWidget);
      expect(
        tester.widget<TextField>(name).controller!.text,
        'Borrador que debe conservarse',
      );
      await _select(tester, '/exercises');
      await tester.tap(find.text('Salir sin guardar'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminExercisesPage), findsOneWidget);
      expect(find.byType(AdminWorkoutEditorPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fallar el permiso comercial conserva contenido y permite reintentar sin recargarlo',
    (tester) async {
      _size(tester, const Size(1440, 1000));
      final fixture = _Fixture()..accounts.fail = true;
      await _mount(tester, fixture);
      expect(_nav('/accounts'), findsNothing);
      expect(_nav('/exercises'), findsOneWidget);
      expect(find.text('Policía Nacional · Acceso'), findsOneWidget);
      fixture.accounts.fail = false;
      await tester.ensureVisible(find.text('Reintentar permisos'));
      await tester.tap(find.text('Reintentar permisos'));
      await tester.pumpAndSettle();
      expect(_nav('/accounts'), findsOneWidget);
      expect(fixture.programs.reads, 1);
      expect(fixture.accounts.reads, 0);
    },
  );

  testWidgets(
    'un editor sin permiso de cuentas no ve Gestión ni consulta su directorio',
    (tester) async {
      _size(tester, const Size(1440, 1000));
      final fixture = _Fixture()..accounts.allowed = false;
      await _mount(tester, fixture);
      expect(_nav('/accounts'), findsNothing);
      expect(find.text('Gestión'), findsNothing);
      expect(_nav('/exercises'), findsOneWidget);
      expect(fixture.accounts.reads, 0);
    },
  );

  testWidgets(
    'sin permiso administrativo no aparecen destinos ni se consulta contenido',
    (tester) async {
      _size(tester, const Size(1440, 1000));
      final fixture = _Fixture()..programs.allowed = false;
      await _mount(tester, fixture, path: '/exercises');
      expect(_nav('/exercises'), findsNothing);
      expect(fixture.exercises.reads, 0);
      expect(fixture.programs.reads, 0);
      expect(find.textContaining('no tiene permiso'), findsOneWidget);
    },
  );

  testWidgets(
    'el login queda fuera del marco y no consulta permisos ni catálogos',
    (tester) async {
      final fixture = _Fixture();
      await _mount(
        tester,
        fixture,
        path: '/sessions/new',
        authenticated: false,
      );
      expect(find.text('Acceso al admin'), findsOneWidget);
      expect(_nav('/sessions'), findsNothing);
      expect(find.byTooltip('Cerrar sesión'), findsNothing);
      expect(
        fixture.programs.reads +
            fixture.workouts.reads +
            fixture.accounts.reads,
        0,
      );
    },
  );

  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'el menú móvil permite cambiar de sección a $width px con texto $scale',
      (tester) async {
        _size(tester, Size(width, 900));
        final router = await _mount(tester, _Fixture(), textScale: scale);
        expect(find.byType(AdminProgramsPage), findsOneWidget);
        expect(_nav('/sessions').hitTestable(), findsNothing);
        await tester.tap(find.byTooltip('Abrir navegación'));
        await tester.pumpAndSettle();
        await _select(tester, '/sessions');
        expect(router.routeInformationProvider.value.uri.path, '/sessions');
        expect(find.byType(AdminProgramWorkoutsPage), findsOneWidget);
        expect(_nav('/sessions').hitTestable(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('capturas del marco real en escritorio, móvil y texto ampliado', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final configFile = File('.dart_tool/package_config.json');
      final config = jsonDecode(await configFile.readAsString()) as Map;
      final flutter = (config['packages'] as List).cast<Map>().singleWhere(
        (package) => package['name'] == 'flutter',
      );
      final fonts = configFile.absolute.uri
          .resolve('${flutter['rootUri']}/')
          .resolve('../../bin/cache/artifacts/material_fonts/');
      for (final (family, filename) in [
        ('Roboto', 'roboto-regular.ttf'),
        ('MaterialIcons', 'materialicons-regular.otf'),
      ]) {
        final bytes = await File.fromUri(fonts.resolve(filename)).readAsBytes();
        await (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    });
    for (final (label, size, scale) in [
      ('desktop', const Size(1440, 1000), 1.0),
      ('mobile', const Size(390, 844), 1.0),
      ('mobile-large-text', const Size(320, 900), 2.0),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await _mount(tester, _Fixture(), textScale: scale);
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage(
            'assets/branding/entrenaop_wordmark_on_dark.png',
            package: 'entrena_ui',
          ),
          tester.element(find.byType(MaterialApp)),
        );
      });
      await tester.pumpAndSettle();
      if (label != 'desktop') {
        await tester.tap(find.byTooltip('Abrir navegación'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('admin-review')),
      );
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 1);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/admin_review')
          ..createSync(recursive: true);
        await File('${directory.path}/$label.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: !const bool.fromEnvironment('CAPTURE_ADMIN'));
}

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_review_page.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/workout_template.dart';

const template = WorkoutTemplate(
  id: 's',
  name: 'Fuerza de glúteos',
  description: 'Técnica controlada',
  estimatedDurationMinutes: 30,
  version: 3,
  blocks: [
    WorkoutBlock(
      id: 'b',
      name: 'Bloque de fuerza',
      format: WorkoutBlockFormat.straightSets,
      rounds: 1,
      restAfterSeconds: 60,
      items: [
        WorkoutItem(
          id: 'i',
          exerciseId: 'e',
          exerciseName: 'Puente de glúteos',
          sets: [
            WorkoutSet(
              id: 'set',
              order: 0,
              targetReps: 12,
              targetRir: 2,
              restAfterSeconds: 90,
            ),
          ],
        ),
      ],
    ),
  ],
);

GuidedProgram programFixture({
  String name = 'Glúteos',
  String status = 'draft',
  String? warmup,
  bool rest = false,
}) => GuidedProgram(
  id: 'p',
  name: name,
  mode: GuidedProgramMode.phased,
  status: status,
  phases: [
    GuidedPhase(
      name: 'Base',
      durationWeeks: 3,
      instructions: 'Completar con técnica estable antes de avanzar.',
      sessions: [
        GuidedSession(
          templateId: 's',
          name: 'Día A',
          warmupId: warmup,
          restPolicy: rest
              ? const GuidedRestPolicy(minimumSeconds: 60, maximumSeconds: 120)
              : const GuidedRestPolicy(),
        ),
        const GuidedSession(templateId: 's', name: 'Día B'),
      ],
    ),
  ],
);

class _Guided extends Fake implements AdminGuidedRepository {
  GuidedProgram current = programFixture();
  List<GuidedWarmup> warmupItems = [];
  bool fail = false, failPublish = false;
  int writes = 0;
  int saves = 0;
  Completer<void>? publishGate;
  @override
  Future<GuidedProgram> program(String id) async {
    if (fail) throw StateError('Sin conexión');
    return current;
  }

  @override
  Future<List<GuidedProgram>> programs() async => [current];
  @override
  Future<List<GuidedProgramCategory>> categories() async => [];
  @override
  Future<String> save(GuidedProgram input, {String? id}) async {
    saves++;
    current = input;
    return 'saved-version';
  }

  @override
  Future<List<GuidedWarmup>> warmups() async => warmupItems;
  @override
  Future<void> setStatus(String id, String status) async {
    writes++;
    if (failPublish) throw StateError('Publicación fallida');
    await publishGate?.future;
  }
}

class _Workouts extends Fake implements AdminWorkoutRepository {
  String status = 'published';
  bool failContent = false,
      failList = false,
      hasWarmup = false,
      adjustable = true;
  final reads = <String>[];
  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async {
    if (failList) throw StateError('Error de catálogo');
    return [
      AdminWorkoutSummary(
        id: 's',
        name: template.name,
        status: status,
        version: 3,
        isRunning: false,
        catalogScope: 'general',
        hasWarmup: hasWarmup,
        supportsAdjustableRest: adjustable,
      ),
    ];
  }

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async {
    reads.add(id);
    if (failContent) throw StateError('Error de contenido');
    if (id == 'warmup-template') {
      return WorkoutTemplate(
        id: id,
        name: 'Activación',
        description: null,
        estimatedDurationMinutes: 5,
        version: 1,
        blocks: template.blocks,
      );
    }
    return template;
  }
}

class _Programs extends Fake implements AdminProgramRepository {
  bool allowed = true;
  @override
  Future<bool> hasAccess() async => allowed;
}

class _Exercises extends Fake implements AdminExerciseRepository {}

Future<GoRouter> _mount(
  WidgetTester tester,
  _Guided guided,
  _Workouts workouts, {
  bool allowed = true,
  Size size = const Size(1100, 1200),
  double scale = 1,
}) async {
  if (const bool.fromEnvironment('CAPTURE_ADMIN_REVIEW')) {
    await tester.runAsync(() async {
      final file = File('.dart_tool/package_config.json');
      final config = jsonDecode(await file.readAsString()) as Map;
      final flutter = (config['packages'] as List).cast<Map>().singleWhere(
        (p) => p['name'] == 'flutter',
      );
      final fonts = file.absolute.uri
          .resolve('${flutter['rootUri']}/')
          .resolve('../../bin/cache/artifacts/material_fonts/');
      for (final (family, name) in [
        ('Roboto', 'roboto-regular.ttf'),
        ('MaterialIcons', 'materialicons-regular.otf'),
      ]) {
        final bytes = await File.fromUri(fonts.resolve(name)).readAsBytes();
        await (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    });
  }
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = createAdminRouter(
    programs: _Programs()..allowed = allowed,
    workouts: workouts,
    exercises: _Exercises(),
    guided: guided,
    onSignOut: () {},
    initialLocation: '/guided-programs/p/review',
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('review-capture'),
      child: MaterialApp.router(
        theme: EntrenaTheme.dark,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> tap(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty || target.hitTestable().evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(target, 250, scrollable: scrollable);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_ADMIN_REVIEW')) return;
  final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('review-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/editorial-review')
      ..createSync(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('confirmación de publicación accesible a 320 px con texto 2×', (
    tester,
  ) async {
    final guided = _Guided(), workouts = _Workouts();
    await _mount(
      tester,
      guided,
      workouts,
      size: const Size(320, 900),
      scale: 2,
    );
    await tap(tester, find.text('Publicar programa'));
    expect(find.text('Publicar en Biblioteca'), findsOneWidget);
    expect(guided.writes, 0);
    await _capture(tester, 'program-confirm-mobile-2x');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'guardar y revisar abre exactamente el borrador guardado y no lo publica',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      final router = await _mount(tester, guided, workouts);
      router.go('/guided-programs/p/edit');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Guardar y revisar'));
      expect(guided.saves, 1);
      expect(guided.writes, 0);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/guided-programs/saved-version/review',
      );
      expect(find.byType(AdminGuidedReviewPage), findsOneWidget);
    },
  );

  testWidgets(
    'revisa calentamiento adjunto y descanso sin iniciar entrenamientos',
    (tester) async {
      final guided = _Guided()
        ..current = programFixture(warmup: 'w', rest: true)
        ..warmupItems = const [
          GuidedWarmup(
            id: 'w',
            templateId: 'warmup-template',
            name: 'Activación',
            version: 1,
            status: 'published',
          ),
        ];
      final workouts = _Workouts();
      await _mount(tester, guided, workouts);
      await tap(tester, find.text('1. Día A'));
      expect(
        find.textContaining('Calentamiento opcional: Activación'),
        findsOneWidget,
      );
      expect(find.textContaining('60–120 s'), findsOneWidget);
      expect(workouts.reads, ['warmup-template', 's']);
      expect(guided.writes, 0);
    },
  );

  testWidgets('bloquea salida y envíos repetidos durante la publicación', (
    tester,
  ) async {
    final gate = Completer<void>();
    final guided = _Guided()..publishGate = gate;
    final workouts = _Workouts();
    final router = await _mount(tester, guided, workouts);
    await tap(tester, find.text('Publicar programa'));
    await tap(tester, find.text('Publicar en Biblioteca'));
    expect(guided.writes, 1);
    expect(find.text('Publicando…'), findsOneWidget);
    router.go('/programs');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/guided-programs/p/review',
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/guided-programs');
    expect(guided.writes, 1);
  });

  testWidgets(
    'muestra recorrido, condiciones, detalle y reutiliza la lectura de una sesión sin publicar',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      await _mount(tester, guided, workouts);
      expect(find.textContaining('Condiciones de avance:'), findsOneWidget);
      await _capture(tester, 'program-desktop');
      expect(workouts.reads, isEmpty);
      await tap(tester, find.text('1. Día A'));
      expect(find.textContaining('12 rep'), findsOneWidget);
      expect(find.textContaining('RIR 2'), findsOneWidget);
      await _capture(tester, 'program-session-expanded');
      expect(workouts.reads, ['s']);
      await tap(tester, find.text('2. Día B'));
      expect(workouts.reads, ['s']);
      expect(guided.writes, 0);
    },
  );

  testWidgets(
    'publicar exige confirmar y los avisos editoriales opcionales no lo bloquean',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      await _mount(tester, guided, workouts);
      await tap(tester, find.text('Publicar programa'));
      expect(
        find.textContaining('no modifica agendas', findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('No crea seguimientos'), findsOneWidget);
      expect(guided.writes, 0);
      await tap(tester, find.text('Seguir revisando'));
      expect(guided.writes, 0);
      await tap(tester, find.text('Publicar programa'));
      await tap(tester, find.text('Publicar en Biblioteca'));
      expect(guided.writes, 1);
    },
  );

  testWidgets(
    'bloquea referencias retiradas, calentamientos duplicados y descansos incompatibles',
    (tester) async {
      final guided = _Guided()
        ..current = programFixture(warmup: 'w', rest: true);
      final workouts = _Workouts()
        ..status = 'archived'
        ..hasWarmup = true
        ..adjustable = false;
      await _mount(tester, guided, workouts);
      await tap(tester, find.text('Actualizar revisión'));
      expect(
        find.textContaining('no está disponible como sesión publicada'),
        findsNWidgets(2),
      );
      expect(find.textContaining('ya incluye calentamiento'), findsOneWidget);
      expect(find.textContaining('no admite el ajuste'), findsOneWidget);
      await tap(tester, find.text('Publicar programa'));
      final button = tester.widget<FilledButton>(
        find
            .ancestor(
              of: find.text('Publicar programa'),
              matching: find.byWidgetPredicate((w) => w is FilledButton),
            )
            .first,
      );
      expect(button.onPressed, isNull);
      expect(guided.writes, 0);
    },
  );

  testWidgets(
    'un fallo de catálogo no se interpreta como revisión correcta y permite reintentar',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts()..failList = true;
      await _mount(tester, guided, workouts);
      expect(
        find.text('No se pudo cargar la revisión del programa.'),
        findsOneWidget,
      );
      expect(find.text('Publicar programa'), findsNothing);
      workouts.failList = false;
      await tap(tester, find.text('Reintentar'));
      await tap(tester, find.text('Publicar programa'));
      expect(find.text('Publicar en Biblioteca'), findsOneWidget);
      expect(guided.writes, 0);
    },
  );

  testWidgets(
    'fallar el contenido bloquea publicación y recupera al reintentar',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts()..failContent = true;
      await _mount(tester, guided, workouts);
      await tap(tester, find.text('1. Día A'));
      await tap(tester, find.text('Publicar programa'));
      expect(
        tester
            .widget<FilledButton>(
              find
                  .ancestor(
                    of: find.text('Publicar programa'),
                    matching: find.byWidgetPredicate((w) => w is FilledButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );
      expect(guided.writes, 0);
      workouts.failContent = false;
      await tap(tester, find.text('Reintentar contenido'));
      await tap(tester, find.text('Publicar programa'));
      expect(find.text('Publicar en Biblioteca'), findsOneWidget);
    },
  );

  testWidgets(
    'detecta cambios de otra pestaña después de confirmar sin publicar contenido nuevo',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      await _mount(tester, guided, workouts);
      await tap(tester, find.text('Publicar programa'));
      guided.current = programFixture(name: 'Contenido cambiado');
      await tap(tester, find.text('Publicar en Biblioteca'));
      expect(guided.writes, 0);
      expect(find.textContaining('han cambiado'), findsOneWidget);
    },
  );

  testWidgets(
    'relee la disponibilidad al confirmar y no publica una sesión recién retirada',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      await _mount(tester, guided, workouts);
      await tap(tester, find.text('Publicar programa'));
      workouts.status = 'archived';
      await tap(tester, find.text('Publicar en Biblioteca'));
      expect(guided.writes, 0);
      expect(find.textContaining('han cambiado'), findsOneWidget);
    },
  );

  testWidgets(
    'un error de publicación conserva la revisión y permite reintentar',
    (tester) async {
      final guided = _Guided()..failPublish = true, workouts = _Workouts();
      await _mount(tester, guided, workouts);
      await tap(tester, find.text('Publicar programa'));
      await tap(tester, find.text('Publicar en Biblioteca'));
      expect(
        find.textContaining('El borrador sigue guardado.'),
        findsOneWidget,
      );
      guided.failPublish = false;
      await tap(tester, find.text('Publicar programa'));
      await tap(tester, find.text('Publicar en Biblioteca'));
      expect(guided.writes, 2);
    },
  );

  testWidgets('la ruta privada no admite acceso sin permiso administrativo', (
    tester,
  ) async {
    final guided = _Guided(), workouts = _Workouts();
    await _mount(tester, guided, workouts, allowed: false);
    expect(find.byType(AdminGuidedReviewPage), findsNothing);
    expect(find.textContaining('no tiene permiso'), findsOneWidget);
    expect(guided.writes, 0);
  });

  testWidgets(
    '320 px y texto ampliado conserva lectura y confirmación sin desbordar',
    (tester) async {
      final guided = _Guided()..current = programFixture(status: 'published'),
          workouts = _Workouts();
      await _mount(
        tester,
        guided,
        workouts,
        size: const Size(320, 900),
        scale: 2,
      );
      await tap(tester, find.text('1. Día A'));
      await tap(tester, find.text('Actualizar revisión'));
      expect(find.text('Publicar programa'), findsNothing);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await _capture(tester, 'program-mobile-2x');
      expect(tester.takeException(), isNull);
      expect(guided.writes, 0);
    },
  );
}

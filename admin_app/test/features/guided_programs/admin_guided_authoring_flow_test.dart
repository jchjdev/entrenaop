import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_work.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_pages.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/guided_session_picker.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_editor_page.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/workout_template.dart';

import '../../../../test/helpers/performance_visual_review.dart';

class _Programs extends Fake implements AdminProgramRepository {
  @override
  Future<bool> hasAccess() async => true;
}

class _Exercises extends Fake implements AdminExerciseRepository {}

class _Checkpoint extends Fake implements AdminGuidedWorkRepository {
  GuidedWork? stored;
  bool failLink = true;
  @override
  Future<GuidedWork?> load(String id) async => stored;
  @override
  Future<GuidedWork> save(GuidedWork work, Map<String, dynamic> state) async {
    final phase = (state['phases'] as List).single as Map;
    if (failLink &&
        (phase['sessions'] as List).isNotEmpty &&
        (phase['pending'] as List).isEmpty) {
      failLink = false;
      throw StateError('Fallo al confirmar el enlace');
    }
    return stored = GuidedWork(
      id: work.id,
      revision: work.revision + 1,
      state: state,
      baseProgramId: work.baseProgramId,
    );
  }
}

class _Guided extends Fake implements AdminGuidedRepository {
  GuidedProgram? saved;
  final warmupItems = <GuidedWarmup>[];
  @override
  Future<List<GuidedProgramCategory>> categories() async => [];
  @override
  Future<List<GuidedWarmup>> warmups() async => warmupItems;
  @override
  Future<String> save(GuidedProgram program, {String? id}) async {
    saved = program;
    return 'program';
  }

  @override
  Future<String> saveWarmup(
    CreatePersonalWorkoutInput input, {
    String? previousId,
  }) async {
    warmupItems.add(
      GuidedWarmup(
        id: 'warmup',
        templateId: 'warmup-template',
        name: input.name,
        version: 1,
        status: 'published',
      ),
    );
    return 'warmup';
  }
}

class _Workouts extends Fake implements AdminWorkoutRepository {
  final inputs = <String, CreatePersonalWorkoutInput>{};
  final published = <String>{};
  final visibility = <String, bool>{};
  int creates = 0, publishes = 0, reads = 0;
  bool failPublish = false, failList = false;
  Completer<void>? publishGate;
  @override
  Future<List<AdminExercise>> listPublicExercises() async => const [
    AdminExercise(id: 'exercise', name: 'Puente de glúteos'),
  ];
  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async {
    reads++;
    if (failList) throw StateError('Sin conexión');
    return [
      for (final entry in inputs.entries)
        AdminWorkoutSummary(
          id: entry.key,
          name: entry.value.name,
          status: published.contains(entry.key) ? 'published' : 'draft',
          version: 1,
          isRunning: true,
          supportsAdjustableRest: false,
          catalogScope: 'general',
          showInLibrary: visibility[entry.key] ?? true,
        ),
    ];
  }

  @override
  Future<String> createDraft(
    String? programId,
    CreatePersonalWorkoutInput input, {
    bool showInLibrary = true,
  }) async {
    expect(programId, isNull);
    final id = 'session-${++creates}';
    inputs[id] = input;
    visibility[id] = showInLibrary;
    return id;
  }

  @override
  Future<void> publishDraft(String id) async {
    publishes++;
    if (failPublish) throw StateError('Sin conexión');
    await publishGate?.future;
    published.add(id);
  }

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async => WorkoutTemplate(
    id: id,
    name: inputs[id]!.name,
    description: null,
    estimatedDurationMinutes: 2,
    version: 1,
    blocks: const [
      WorkoutBlock(
        id: 'running',
        name: 'Carrera',
        format: WorkoutBlockFormat.running,
        rounds: 1,
        restAfterSeconds: 0,
        items: [
          WorkoutItem(
            id: 'item',
            exerciseId: runningExerciseId,
            exerciseName: 'Carrera',
            sets: [
              WorkoutSet(
                id: 'set',
                order: 0,
                targetDistanceMeters: 400,
                targetPaceMinSecondsPerKm: 360,
                targetPaceMaxSecondsPerKm: 360,
                restAfterSeconds: 0,
              ),
            ],
          ),
        ],
      ),
    ],
  );
  @override
  Future<String> revise(String id, CreatePersonalWorkoutInput input) async {
    final next = 'revision-$id';
    inputs.remove(id);
    inputs[next] = input;
    visibility[next] = visibility.remove(id) ?? true;
    return next;
  }
}

Future<GoRouter> _mount(
  WidgetTester tester,
  _Guided guided,
  _Workouts workouts, {
  Size size = const Size(1300, 1500),
  double scale = 1,
  AdminGuidedWorkRepository? work,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = createAdminRouter(
    programs: _Programs(),
    exercises: _Exercises(),
    workouts: workouts,
    guided: guided,
    guidedWork: work,
    onSignOut: () {},
    initialLocation: '/guided-programs/new',
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('review-boundary'),
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
  await tester.enterText(
    find.byKey(const ValueKey('program-field-Nombre del programa')),
    'Glúteos · cuatro sesiones',
  );
  return router;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  if (target.evaluate().isEmpty) {
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

Future<void> _create(WidgetTester tester, String name) async {
  await _tap(tester, find.text('Crear nueva sesión').last);
  expect(find.byType(AdminWorkoutEditorPage), findsOneWidget);
  expect(find.text('Mostrar en Sesiones de EntrenaOP'), findsNothing);
  await tester.enterText(
    find.widgetWithText(TextField, 'Nombre de la sesión'),
    name,
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Distancia (m)'),
    '400',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Ritmo (m:ss/km)'),
    '6:00',
  );
  await _tap(tester, find.text('Guardar en programa'));
  expect(find.byType(AdminWorkoutEditorPage), findsNothing);
}

void main() {
  setUpAll(() => loadReviewFont(always: true));
  testWidgets('doble pulsación al crear despliega un solo editor', (
    tester,
  ) async {
    await _mount(tester, _Guided(), _Workouts());
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Crear nueva sesión'),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(AdminWorkoutEditorPage), findsOneWidget);
    await _tap(tester, find.text('Recoger sesión'));
    expect(find.byType(AdminWorkoutEditorPage), findsNothing);
  });
  testWidgets(
    'reintentar el guardado final del enlace no duplica ni deja pendientes',
    (tester) async {
      final checkpoint = _Checkpoint(), workouts = _Workouts();
      await _mount(tester, _Guided(), workouts, work: checkpoint);
      await _tap(tester, find.text('Crear nueva sesión'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la sesión'),
        'Recuperar enlace',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Distancia (m)'),
        '400',
      );
      await _tap(tester, find.text('Guardar en programa'));
      expect(find.text('Reintentar enlace'), findsOneWidget);
      await _tap(tester, find.text('Reintentar enlace'));
      expect(find.text('1 sesión en esta rutina'), findsOneWidget);
      final phase = (checkpoint.stored!.state['phases'] as List).single as Map;
      expect((phase['sessions'] as List).single['id'], 'session-1');
      expect(phase['pending'], isEmpty);
      expect(workouts.creates, 1);
    },
  );
  for (final (size, scale) in [
    (const Size(1300, 1000), 1.0),
    (const Size(390, 900), 1.0),
    (const Size(320, 900), 2.0),
  ]) {
    testWidgets(
      'editor integrado conserva programa y cierre accesible a $size / $scale',
      (tester) async {
        final workouts = _Workouts();
        final router = await _mount(
          tester,
          _Guided(),
          workouts,
          size: size,
          scale: scale,
        );
        final location = router.routeInformationProvider.value.uri;
        await _tap(tester, find.text('Crear nueva sesión'));
        expect(router.routeInformationProvider.value.uri, location);
        expect(find.byType(AdminGuidedEditorPage), findsOneWidget);
        expect(find.byType(AdminWorkoutEditorPage), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AdminWorkoutEditorPage),
            matching: find.byType(Scaffold),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(AdminWorkoutEditorPage),
            matching: find.byType(ListView),
          ),
          findsNothing,
        );
        expect(find.text('Recoger sesión').hitTestable(), findsOneWidget);
        expect(find.text('Publicar sesión'), findsNothing);
        await capturePerformanceWidget(
          tester,
          'program-session-inline-${size.width.toInt()}-${scale.toInt()}',
        );
        await _tap(tester, find.text('Recoger sesión'));
        expect(find.byType(AdminWorkoutEditorPage), findsNothing);
        expect(workouts.creates, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'crea cuatro borradores dentro del programa sin cambiar de ruta ni publicar sesiones',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      final router = await _mount(tester, guided, workouts);
      final location = router.routeInformationProvider.value.uri;
      for (var i = 1; i <= 4; i++) {
        await _create(tester, 'Sesión $i');
        expect(workouts.published, isEmpty);
        expect(router.routeInformationProvider.value.uri, location);
        expect(find.byType(AdminGuidedEditorPage), findsOneWidget);
        expect(
          find.text('$i ${i == 1 ? 'sesión' : 'sesiones'} en esta rutina'),
          findsOneWidget,
        );
      }
      await _tap(tester, find.text('Guardar borrador'));
      expect(guided.saved!.name, 'Glúteos · cuatro sesiones');
      expect(guided.saved!.phases.single.sessions.map((s) => s.templateId), [
        'session-1',
        'session-2',
        'session-3',
        'session-4',
      ]);
      expect(workouts.creates, 4);
      expect(workouts.publishes, 0);
      expect(workouts.visibility.values.every((v) => !v), isTrue);
      expect(find.text('¿Salir sin guardar?'), findsNothing);
    },
  );

  testWidgets(
    'cerrar una sesión sin guardar conserva el programa y pide confirmar',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      await _mount(tester, guided, workouts);
      await _tap(tester, find.text('Crear nueva sesión'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la sesión'),
        'Sin guardar',
      );
      await _tap(tester, find.text('Recoger sesión'));
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      await _tap(tester, find.text('Continuar'));
      expect(find.byType(AdminWorkoutEditorPage), findsOneWidget);
      await _tap(tester, find.text('Recoger sesión'));
      await _tap(tester, find.text('Salir sin guardar'));
      expect(find.byType(AdminWorkoutEditorPage), findsNothing);
      expect(workouts.creates, 0);
      expect(find.text('0 sesiones en esta rutina'), findsOneWidget);
    },
  );

  testWidgets('desplazarse por el programa conserva la sesión sin guardar', (
    tester,
  ) async {
    await _mount(tester, _Guided(), _Workouts(), size: const Size(390, 900));
    await _tap(tester, find.text('Crear nueva sesión'));
    final name = find.widgetWithText(TextField, 'Nombre de la sesión');
    await tester.enterText(name, 'Borrador que permanece');
    FocusManager.instance.primaryFocus?.unfocus();
    final scroll = Scrollable.of(tester.element(name)).position;
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    scroll.jumpTo(scroll.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(name).controller!.text,
      'Borrador que permanece',
    );
    await _tap(tester, find.text('Recoger sesión'));
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await _tap(tester, find.text('Continuar'));
    expect(
      tester.widget<TextField>(name).controller!.text,
      'Borrador que permanece',
    );
  });

  testWidgets(
    'navegar fuera consulta también el borrador de sesión integrado',
    (tester) async {
      final router = await _mount(
        tester,
        _Guided(),
        _Workouts(),
        work: _Checkpoint(),
      );
      await _tap(tester, find.text('Crear nueva sesión'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la sesión'),
        'No perder',
      );
      router.go('/guided-programs');
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      await _tap(tester, find.text('Continuar'));
      expect(find.byType(AdminWorkoutEditorPage), findsOneWidget);
      router.go('/guided-programs');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Salir sin guardar'));
      expect(find.byType(AdminWorkoutEditorPage), findsNothing);
      expect(find.byType(AdminGuidedCatalogPage), findsOneWidget);
    },
  );

  testWidgets(
    'fallar el enlace conserva el ID y reintentar no crea otra sesión',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      await _mount(tester, guided, workouts);
      await _tap(tester, find.text('Crear nueva sesión'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la sesión'),
        'Recuperable',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Distancia (m)'),
        '400',
      );
      workouts.failList = true;
      await _tap(tester, find.text('Guardar en programa'));
      expect(find.text('Reintentar enlace'), findsOneWidget);
      expect(workouts.creates, 1);
      workouts.failList = false;
      await _tap(tester, find.text('Reintentar enlace'));
      expect(find.text('1 sesión en esta rutina'), findsOneWidget);
      expect(workouts.creates, 1);
      expect(workouts.publishes, 0);
    },
  );

  testWidgets(
    'recoger un enlace fallido conserva el ID para retomarlo sin duplicar',
    (tester) async {
      final workouts = _Workouts();
      await _mount(tester, _Guided(), workouts);
      await _tap(tester, find.text('Crear nueva sesión'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la sesión'),
        'Pendiente recuperable',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Distancia (m)'),
        '400',
      );
      workouts.failList = true;
      await _tap(tester, find.text('Guardar en programa'));
      expect(find.text('Reintentar enlace'), findsOneWidget);
      await _tap(tester, find.text('Recoger sesión'));
      expect(find.byType(AdminWorkoutEditorPage), findsNothing);
      expect(find.text('Retomar sesión'), findsOneWidget);
      workouts.failList = false;
      await _tap(tester, find.text('Retomar sesión'));
      expect(find.text('1 sesión en esta rutina'), findsOneWidget);
      expect(find.text('Retomar sesión'), findsNothing);
      expect(workouts.creates, 1);
      expect(workouts.publishes, 0);
    },
  );

  for (final published in [false, true]) {
    testWidgets(
      'abrir ${published ? 'nueva versión' : 'editar borrador'} no crea ni guarda ninguna sesión',
      (tester) async {
        final workouts = _Workouts();
        await _mount(tester, _Guided(), workouts);
        await _create(tester, 'Sesión ya guardada');
        if (published) workouts.published.add('session-1');
        await _tap(tester, find.text('Revisar sesión'));
        await _tap(
          tester,
          find.text(
            published ? 'Crear nueva versión en borrador' : 'Editar borrador',
          ),
        );
        expect(find.byType(AdminWorkoutEditorPage), findsOneWidget);
        expect(workouts.creates, 1);
        expect(workouts.inputs.keys, ['session-1']);
        expect(workouts.inputs['session-1']!.name, 'Sesión ya guardada');
        await _tap(tester, find.text('Recoger sesión'));
        expect(workouts.inputs.keys, ['session-1']);
      },
    );
  }

  testWidgets(
    'editar dentro del programa conserva ruta y enlaza la identidad devuelta',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      final router = await _mount(tester, guided, workouts);
      final location = router.routeInformationProvider.value.uri;
      await _create(tester, 'Sesión original');
      await _tap(tester, find.text('Revisar sesión'));
      expect(find.byType(AdminWorkoutPreviewPage), findsOneWidget);
      expect(find.text('Publicar sesión'), findsNothing);
      await _tap(tester, find.text('Editar borrador'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la sesión'),
        'Sesión revisada',
      );
      await _tap(tester, find.text('Guardar en programa'));
      expect(router.routeInformationProvider.value.uri, location);
      expect(find.text('1 sesión en esta rutina'), findsOneWidget);
      await _tap(tester, find.text('Guardar borrador'));
      expect(
        guided.saved!.phases.single.sessions.single.templateId,
        'revision-session-1',
      );
      expect(workouts.publishes, 0);
    },
  );

  testWidgets(
    'crea y adjunta un calentamiento con el editor existente y conserva el programa',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      await _mount(tester, guided, workouts);
      await _create(tester, 'Sesión con activación');
      await _tap(tester, find.text('Crear y adjuntar calentamiento'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la sesión'),
        'Activación',
      );
      await _tap(tester, find.text('Buscar ejercicio del catálogo'));
      await _tap(tester, find.text('Puente de glúteos').last);
      await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '10');
      await _tap(tester, find.text('Guardar calentamiento'));
      expect(find.byType(AdminGuidedEditorPage), findsOneWidget);
      await _tap(tester, find.text('Guardar borrador'));
      expect(guided.saved!.phases.single.sessions.single.warmupId, 'warmup');
      expect(guided.saved!.name, 'Glúteos · cuatro sesiones');
      expect(workouts.creates, 1);
    },
  );

  testWidgets('la sesión nueva se incorpora a su fase sin mezclar las demás', (
    tester,
  ) async {
    final guided = _Guided(), workouts = _Workouts();
    await _mount(tester, guided, workouts);
    await _create(tester, 'Base');
    await _tap(tester, find.text('Por fases'));
    await _tap(tester, find.text('Añadir fase'));
    await _create(tester, 'Progresión');
    final scroll = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      final field = find
          .byKey(
            const ValueKey(
              'program-field-Indicaciones y condiciones de avance',
            ),
          )
          .at(i);
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Avanzar tras revisar la fase');
    }
    await _tap(tester, find.text('Guardar borrador'));
    expect(guided.saved!.mode, GuidedProgramMode.phased);
    expect(guided.saved!.phases[0].sessions.single.templateId, 'session-1');
    expect(guided.saved!.phases[1].sessions.single.templateId, 'session-2');
  });

  testWidgets(
    'selector con búsqueda y borradores admite teclado y texto 2× a 320 px',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: GuidedSessionPicker(
              sessions: [
                AdminWorkoutSummary(
                  id: 'hidden',
                  name: 'Sesión de fuerza de la fase avanzada',
                  status: 'published',
                  version: 1,
                  isRunning: false,
                  catalogScope: 'general',
                  showInLibrary: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Oculta como sesión suelta'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

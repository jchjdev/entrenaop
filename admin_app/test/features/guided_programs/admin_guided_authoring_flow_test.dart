import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
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

class _Programs extends Fake implements AdminProgramRepository {
  @override
  Future<bool> hasAccess() async => true;
}

class _Exercises extends Fake implements AdminExerciseRepository {}

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
  int creates = 0, publishes = 0, reads = 0;
  bool failPublish = false;
  Completer<void>? publishGate;
  @override
  Future<List<AdminExercise>> listPublicExercises() async => const [
    AdminExercise(id: 'exercise', name: 'Puente de glúteos'),
  ];
  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async {
    reads++;
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
        ),
    ];
  }

  @override
  Future<String> createDraft(
    String? programId,
    CreatePersonalWorkoutInput input,
  ) async {
    expect(programId, isNull);
    final id = 'session-${++creates}';
    inputs[id] = input;
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
    return next;
  }
}

Future<GoRouter> _mount(
  WidgetTester tester,
  _Guided guided,
  _Workouts workouts,
) async {
  await tester.binding.setSurfaceSize(const Size(1300, 1500));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = createAdminRouter(
    programs: _Programs(),
    exercises: _Exercises(),
    workouts: workouts,
    guided: guided,
    onSignOut: () {},
    initialLocation: '/guided-programs/new',
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nombre del programa'),
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
  await _tap(tester, find.text('Guardar borrador'));
  expect(find.byType(AdminWorkoutPreviewPage), findsOneWidget);
}

Future<void> _confirmPublication(WidgetTester tester) async {
  await _tap(tester, find.text('Publicar en biblioteca general'));
  expect(find.textContaining('visible para todos'), findsOneWidget);
  await _tap(tester, find.text('Publicar en biblioteca general').last);
}

void main() {
  testWidgets(
    'crea cuatro sesiones con editores y router reales, publica explícitamente y guarda sus identidades',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      await _mount(tester, guided, workouts);
      for (var i = 1; i <= 4; i++) {
        await _create(tester, 'Sesión $i');
        expect(workouts.published, hasLength(i - 1));
        await _confirmPublication(tester);
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
      expect(workouts.publishes, 4);
      expect(find.text('¿Salir sin guardar?'), findsNothing);
    },
  );

  testWidgets(
    'cancelar conserva borrador recuperable y fallar publicación no crea duplicados',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      await _mount(tester, guided, workouts);
      await _create(tester, 'Sesión recuperable');
      await _tap(tester, find.text('Publicar en biblioteca general'));
      await _tap(tester, find.text('Cancelar'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('0 sesiones en esta rutina'), findsOneWidget);
      await _tap(tester, find.text('Guardar borrador'));
      expect(guided.saved, isNull);
      expect(find.textContaining('Tienes sesiones pendientes'), findsOneWidget);
      await _tap(tester, find.text('Elegir del catálogo'));
      await _tap(tester, find.widgetWithText(ChoiceChip, 'Borradores'));
      await _tap(
        tester,
        find.descendant(
          of: find.byType(GuidedSessionPicker),
          matching: find.text('Sesión recuperable'),
        ),
      );
      workouts.failPublish = true;
      await _confirmPublication(tester);
      expect(find.byType(AdminWorkoutPreviewPage), findsOneWidget);
      expect(
        find.textContaining('No se pudo publicar la sesión.'),
        findsOneWidget,
      );
      workouts.failPublish = false;
      await _confirmPublication(tester);
      expect(find.text('1 sesión en esta rutina'), findsOneWidget);
      expect(workouts.creates, 1);
      expect(workouts.publishes, 2);
    },
  );

  testWidgets(
    'editar antes de publicar incorpora la identidad revisada y bloquea salir durante publicación',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      final router = await _mount(tester, guided, workouts);
      await _create(tester, 'Sesión original');
      await _tap(tester, find.text('Editar borrador'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la sesión'),
        'Sesión revisada',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Distancia (m)'),
        '400',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Ritmo (m:ss/km)'),
        '6:00',
      );
      await _tap(tester, find.text('Guardar revisión como borrador'));
      expect(tester.takeException(), isNull, reason: 'regreso de la revisión');
      expect(find.byType(AdminWorkoutPreviewPage), findsOneWidget);
      workouts.publishGate = Completer<void>();
      await _tap(tester, find.text('Publicar en biblioteca general'));
      await tester.tap(find.text('Publicar en biblioteca general').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Publicando…'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(router.state.uri.path, '/sessions/revision-session-1');
      router.pop();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.takeException(),
        isNull,
        reason: 'salida bloqueada por publicación',
      );
      expect(find.byType(AdminWorkoutPreviewPage), findsOneWidget);
      expect(router.state.uri.path, '/sessions/revision-session-1');
      expect(workouts.publishes, 1);
      workouts.publishGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'publicación completada');
      expect(
        find.byType(AdminWorkoutPreviewPage),
        findsNothing,
        reason: 'publicación devuelve al programa',
      );
      expect(find.text('1 sesión en esta rutina'), findsOneWidget);
      await _tap(tester, find.text('Guardar borrador'));
      expect(
        guided.saved!.phases.single.sessions.single.templateId,
        'revision-session-1',
      );
    },
  );

  testWidgets(
    'crea y adjunta un calentamiento con el editor existente y conserva el programa',
    (tester) async {
      final guided = _Guided(), workouts = _Workouts();
      await _mount(tester, guided, workouts);
      await _create(tester, 'Sesión con activación');
      await _confirmPublication(tester);
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
    await _confirmPublication(tester);
    await _tap(tester, find.text('Por fases'));
    await _tap(tester, find.text('Añadir fase'));
    await _create(tester, 'Progresión');
    await _confirmPublication(tester);
    final scroll = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      final field = find
          .widgetWithText(TextFormField, 'Indicaciones y condiciones de avance')
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
          home: const Scaffold(body: GuidedSessionPicker(sessions: [])),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

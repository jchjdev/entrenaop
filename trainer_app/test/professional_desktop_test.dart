import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_trainer/trainer_client_navigation.dart';
import 'package:entrenaop_trainer/trainer_client_workspace.dart';

import 'trainer_client_workspace_test.dart' show WorkspaceFixture;

import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:entrenaop_trainer/trainer_clients_page.dart';
import 'package:entrenaop_trainer/trainer_workout_pages.dart';

import '../../test/helpers/performance_visual_review.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/strength_set_fields.dart';
import 'package:workout_editor_ui/program_session_catalog.dart';
import 'package:entrenaop_trainer/trainer_program_pages.dart';
import 'package:entrenaop_trainer/trainer_agenda_page.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import 'trainer_workout_flow_test.dart' show privateRecipe, WorkoutFixture;
import 'trainer_program_flow_test.dart' show ProgramFixture;
import 'trainer_agenda_edit_test.dart' show AgendaEditFixture;

Widget desktop(Widget child) => MaterialApp(
  theme: EntrenaTheme.dark,
  home: ProfessionalWorkspaceScope(desktop: true, child: child),
);

Future<void> resize(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> dragTo(
  WidgetTester t,
  Finder source,
  Offset target, {
  bool cancel = false,
  bool settle = true,
}) async {
  final gesture = await t.startGesture(
    t.getCenter(source),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(const Offset(12, 12));
  await t.pump();
  await gesture.moveTo(target);
  await t.pump(const Duration(milliseconds: 100));
  if (cancel) {
    await gesture.cancel();
  } else {
    await gesture.up();
  }
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  setUpAll(loadReviewFont);
  for (final running in [false, true]) {
    testWidgets(
      'creador a 1366 × 768 ajusta columnas y conserva receta: $running',
      (t) async {
        await resize(t, const Size(1366, 768));
        await t.pumpWidget(
          MaterialApp(
            theme: EntrenaTheme.dark,
            home: RepaintBoundary(
              key: const ValueKey('review-boundary'),
              child: TrainerShell(
                location: '/workouts/new',
                child: WorkoutEditorPage(
                  title: 'Crear sesión',
                  heading: 'Receta',
                  instructions: 'Prepara tu sesión',
                  saveLabel: 'Guardar sesión',
                  fixedRunningMode: running,
                  originalTemplate: running ? null : privateRecipe,
                  loadExercises: () async => [
                    const WorkoutEditorExercise(
                      id: 'exercise',
                      name: 'Dominadas',
                    ),
                  ],
                  onSave: (_) async => 'saved',
                  onSaved: (_) {},
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final name = find.byKey(const ValueKey('workout-name'));
        await t.enterText(
          name,
          running ? 'Series de carrera' : 'Fuerza de la semana',
        );
        final controller = t.widget<TextField>(name).controller;
        final inspector = find.byKey(
          const ValueKey('professional-inspector-pane'),
        );
        final handle = find.byKey(
          const ValueKey('professional-inspector-resize'),
        );
        final before = t.getSize(inspector).width;
        expect(before, 400);
        await t.drag(handle, const Offset(-60, 0));
        await t.pumpAndSettle();
        expect(t.getSize(inspector).width, greaterThan(before));
        expect(t.widget<TextField>(name).controller, same(controller));
        expect(
          controller!.text,
          running ? 'Series de carrera' : 'Fuerza de la semana',
        );
        expect(find.text('Guardar sesión').hitTestable(), findsOneWidget);
        expect(t.takeException(), isNull);
        await capturePerformanceWidget(
          t,
          running
              ? 'trainer-running-1366-resized'
              : 'trainer-strength-1366-resized',
        );
      },
    );
  }
  testWidgets(
    'marco real de escritorio mantiene navegación y biblioteca visibles',
    (t) async {
      await resize(t, const Size(1920, 1100));
      final workouts = WorkoutFixture();
      final router = GoRouter(
        initialLocation: '/workouts',
        routes: [
          ShellRoute(
            builder: (_, state, child) =>
                TrainerShell(location: state.uri.path, child: child),
            routes: [
              GoRoute(
                path: '/clients',
                builder: (_, _) => TrainerClientsPage(
                  repository: FakeTrainerRepository(),
                  onOpenWorkouts: () {},
                ),
              ),
              GoRoute(
                path: '/workouts',
                builder: (_, _) => TrainerWorkoutLibraryPage(
                  repository: workouts,
                  accessRepository: FakeTrainerRepository(),
                ),
              ),
              GoRoute(
                path: '/programs',
                builder: (_, _) => TrainerProgramEditorPage(
                  repository: ProgramFixture(),
                  workouts: workouts,
                  programId: 'program',
                ),
              ),
              GoRoute(
                path: '/agenda',
                builder: (_, _) => TrainerAgendaPage(
                  repository: AgendaEditFixture(),
                  workouts: workouts,
                  access: FakeTrainerRepository(),
                  now: DateTime(2026, 10, 21),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('review-boundary'),
          child: MaterialApp.router(
            theme: EntrenaTheme.dark,
            routerConfig: router,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('trainer-nav-/clients')).hitTestable(),
        findsOneWidget,
      );
      await capturePerformanceWidget(t, 'trainer-desktop-library');
      router.go('/programs');
      await t.pumpAndSettle();
      expect(find.text('Mis sesiones privadas'), findsOneWidget);
      expect(find.text('Estructura del programa'), findsOneWidget);
      await capturePerformanceWidget(t, 'trainer-desktop-program');
      router.go('/agenda');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('agenda-view-week')));
      await t.pumpAndSettle();
      expect(find.text('Sesiones para asignar'), findsOneWidget);
      await capturePerformanceWidget(t, 'trainer-desktop-agenda');
      router.go('/clients');
      await t.pumpAndSettle();
      expect(find.byType(EntrenaWordmark), findsOneWidget);
      expect(find.text('ESPACIO PROFESIONAL'), findsNothing);
      expect(
        find.widgetWithText(OutlinedButton, 'Mis sesiones privadas'),
        findsNothing,
      );
      expect(find.byTooltip('Actualizar'), findsOneWidget);
      await capturePerformanceWidget(t, 'trainer-desktop-clients');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'biblioteca arrastra a fuerza, conserva dosis y no guarda hasta confirmar',
    (t) async {
      await resize(t, const Size(1600, 1600));
      CreatePersonalWorkoutInput? saved;
      await t.pumpWidget(
        desktop(
          WorkoutEditorPage(
            title: 'Editor',
            heading: 'Receta',
            instructions: 'Ensayo',
            saveLabel: 'Guardar ensayo',
            originalTemplate: privateRecipe,
            loadExercises: () async => [
              const WorkoutEditorExercise(id: 'exercise', name: 'Dominadas'),
              const WorkoutEditorExercise(
                id: 'private',
                name: 'Mi ejercicio de prueba',
              ),
            ],
            onSave: (v) async {
              saved = v;
              return 'saved';
            },
            onSaved: (_) {},
          ),
        ),
      );
      await t.pumpAndSettle();
      final target = find
          .byType(DragTarget<ProfessionalLibraryDrag<WorkoutEditorExercise>>)
          .first;
      final source = find.widgetWithText(ListTile, 'Mi ejercicio de prueba');
      await dragTo(t, source, t.getCenter(target), cancel: true);
      expect(
        find.byType(StrengthSetFields),
        findsOneWidget,
        reason: 'Cancelar conserva la única posición original.',
      );
      await dragTo(t, source, t.getCenter(target));
      expect(saved, isNull);
      expect(
        find.text('Cambiar ejercicio · Mi ejercicio de prueba'),
        findsOneWidget,
      );
      final dose = find
          .descendant(
            of: find.byType(StrengthSetFields).last,
            matching: find.byType(TextField),
          )
          .first;
      await t.enterText(dose, '8');
      final rows = find.byWidgetPredicate(
        (w) =>
            w is ListTile &&
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith(
              'exercise-properties-',
            ),
      );
      expect(rows, findsNWidgets(2));
      await t.tap(rows.first);
      await t.pumpAndSettle();
      expect(t.widget<TextField>(dose).controller!.text, '10');
      await t.tap(rows.last);
      await t.pumpAndSettle();
      expect(t.widget<TextField>(dose).controller!.text, '8');
      expect(find.text('Guardar ensayo').hitTestable(), findsOneWidget);
      final name = t
          .widget<TextField>(find.byKey(const ValueKey('workout-name')))
          .controller!;
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.binding.setSurfaceSize(const Size(950, 1600));
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('workout-name')))
            .controller,
        same(name),
      );
      expect(name.text, privateRecipe.name);
      await t.scrollUntilVisible(
        find.text('Guardar ensayo'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(find.text('Guardar ensayo'));
      await t.tap(find.text('Guardar ensayo'));
      await t.pumpAndSettle();
      expect(saved!.blocks.single.exercises.map((e) => e.exerciseId), [
        'exercise',
        'private',
      ]);
      expect(saved!.blocks.single.exercises.first.sets.single.targetValue, 10);
      expect(saved!.blocks.single.exercises.first.sets.single.targetLoadKg, 5);
      expect(saved!.blocks.single.exercises.last.sets.first.targetValue, 8);
      expect(t.takeException(), isNull);
      await t.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'programa reordena fases y recibe sesiones desde el catálogo común',
    (t) async {
      await resize(t, const Size(1700, 6500));
      final repo = ProgramFixture();
      await t.pumpWidget(
        desktop(
          TrainerProgramEditorPage(
            repository: repo,
            workouts: WorkoutFixture(),
            programId: 'program',
          ),
        ),
      );
      await t.pumpAndSettle();
      final phases = find.byKey(const ValueKey('program-phase-handle-1'));
      final first = find.byKey(const ValueKey('program-phase-handle-0'));
      await dragTo(t, phases, t.getTopLeft(first) + const Offset(20, -8));
      final names = t
          .widgetList<TextFormField>(
            find.byKey(
              const ValueKey('program-field-Nombre de la fase'),
              skipOffstage: false,
            ),
          )
          .map((f) => f.controller!.text)
          .toList();
      expect(names, ['Progresión', 'Base']);
      final source = find.widgetWithText(ListTile, privateRecipe.name);
      final target = find
          .byType(DragTarget<ProfessionalLibraryDrag<ProgramSessionSummary>>)
          .first;
      await dragTo(t, source, t.getCenter(target));
      expect(repo.saved, isEmpty);
      await t.ensureVisible(find.text('Guardar programa privado'));
      await t.tap(find.text('Guardar programa privado'));
      await t.pumpAndSettle();
      expect(repo.saved.single.program.phases.first.name, 'Progresión');
      expect(repo.saved.single.program.phases.first.sessions.length, 2);
      expect(repo.saved.single.program.phases.last.sessions.length, 1);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'guardar revela los campos inválidos de una fase plegada sin perder sus sesiones',
    (t) async {
      await resize(t, const Size(1700, 2000));
      final repo = ProgramFixture();
      await t.pumpWidget(
        desktop(
          TrainerProgramEditorPage(
            repository: repo,
            workouts: WorkoutFixture(),
            programId: 'program',
          ),
        ),
      );
      await t.pumpAndSettle();
      final configure = find.text('Configurar fase').first;
      await t.tap(configure);
      await t.pumpAndSettle();
      final name = find
          .byKey(const ValueKey('program-field-Nombre de la fase'))
          .first;
      await t.enterText(name, '');
      await t.tap(configure);
      await t.pumpAndSettle();
      expect(find.text('Completa este campo.'), findsNothing);
      await t.tap(find.text('Guardar programa privado'));
      await t.pumpAndSettle();
      expect(find.text('Completa este campo.'), findsOneWidget);
      expect(repo.saved, isEmpty);
      await t.enterText(name, 'Base recuperada');
      await t.tap(find.text('Guardar programa privado'));
      await t.pumpAndSettle();
      expect(repo.saved.single.program.phases.first.name, 'Base recuperada');
      expect(
        repo.saved.single.program.phases.first.sessions.single.name,
        'Fuerza A',
      );
      expect(repo.saved.single.program.phases.last.name, 'Progresión');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('soltar en agenda revisa destinatario y no asigna al cancelar', (
    t,
  ) async {
    await resize(t, const Size(1700, 1500));
    final workouts = WorkoutFixture();
    final access = FakeTrainerRepository()..active = [trainerRelation('Ana')];
    final moves = <DateTime>[];
    await t.pumpWidget(
      desktop(
        TrainerAgendaPage(
          repository: AgendaEditFixture(),
          workouts: workouts,
          access: access,
          now: DateTime(2026, 10, 21),
          onMove: (_, date) async => moves.add(date),
        ),
      ),
    );
    await t.pumpAndSettle();
    final source = find.widgetWithText(ListTile, privateRecipe.name);
    final target = find.byKey(const ValueKey('agenda-drop-2026-10-22'));
    await dragTo(t, source, t.getCenter(target), settle: false);
    expect(find.text('Asignar sesión privada'), findsOneWidget);
    expect(workouts.assigned, isEmpty);
    await t.tap(find.text('Volver'));
    await t.pumpAndSettle();
    expect(workouts.assigned, isEmpty);
    expect(moves, isEmpty);
    final libraryReads = workouts.libraryReads;
    await dragTo(t, source, t.getCenter(target), settle: false);
    await t.pump(const Duration(milliseconds: 350));
    await t.tap(find.byType(DropdownButtonFormField<String>).last);
    await t.pump(const Duration(milliseconds: 350));
    await t.tap(find.text('Ana').last);
    await t.pump(const Duration(milliseconds: 350));
    expect(workouts.libraryReads, libraryReads);
    expect(find.byType(RadioListTile<String>), findsNothing);
    expect(find.text('Sesión seleccionada'), findsOneWidget);
    expect(find.text('Fecha: 22/10/2026'), findsOneWidget);
    expect(workouts.assigned, isEmpty);
    final confirm = find.widgetWithText(FilledButton, 'Asignar sesión');
    expect(confirm.hitTestable(), findsOneWidget);
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(workouts.assigned.single.template, workouts.entry.id);
    expect(workouts.assigned.single.date, DateTime(2026, 10, 22));
    await t.tap(find.byKey(const ValueKey('agenda-view-week')));
    await t.pumpAndSettle();
    final card = find.byKey(const ValueKey('agenda-board-drag-one'));
    final destination = find.byKey(
      const ValueKey('agenda-board-drop-2026-10-22'),
    );
    await dragTo(t, card, t.getTopLeft(destination) + const Offset(60, 80));
    expect(moves, [DateTime(2026, 10, 22)]);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'pestañas conservan notas y pasar a conversación respeta el guard de salida',
    (t) async {
      await resize(t, const Size(1400, 1200));
      final repo = WorkspaceFixture();
      final exits = WorkflowExitRegistry();
      final router = GoRouter(
        initialLocation: '/clients/pupil?area=notes',
        routes: [
          ShellRoute(
            builder: (_, state, child) =>
                TrainerClientNavigation.wrap(state.uri, child),
            routes: [
              GoRoute(
                path: '/clients/:id',
                onExit: (_, state) => exits.requestExit(state.pageKey),
                builder: (_, state) => WorkflowExitScope(
                  controller: exits.controller(state.pageKey),
                  child: TrainerClientWorkspacePage(
                    key: ValueKey(state.pathParameters['id']),
                    repository: repo,
                    clientId: state.pathParameters['id']!,
                    area: state.uri.queryParameters['area'] ?? 'progress',
                  ),
                ),
              ),
              GoRoute(
                path: '/clients/:id/conversation',
                builder: (_, _) => const Scaffold(
                  body: Text('Conversación autorizada de ensayo'),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await t.pumpAndSettle();
      final semantics = t.ensureSemantics();
      final labels = t.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.getSemanticsData().label)
          .toList();
      for (final label in [
        'Planificación',
        'Resultados',
        'Técnica',
        'Evolución',
        'Formularios',
        'Conversación',
        'Notas',
        'Historial',
      ]) {
        expect(
          labels.any((text) => text.contains(label)),
          isTrue,
          reason: '$label debe ser accesible junto a la ruta activa',
        );
      }
      semantics.dispose();
      final notes = find.widgetWithText(TextField, 'Notas internas');
      await t.enterText(notes, 'Mi nota sin guardar');
      final controller = t.widget<TextField>(notes).controller;
      await t.tap(find.text('Evolución'));
      await t.pumpAndSettle();
      expect(find.text('Notas del preparador'), findsNothing);
      expect(find.text('Evolución del servicio'), findsOneWidget);
      await t.tap(find.text('Notas'));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(notes).controller, same(controller));
      expect(controller!.text, 'Mi nota sin guardar');
      await t.tap(find.text('Conversación'));
      await t.pumpAndSettle();
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      expect(find.text('Conversación autorizada de ensayo'), findsNothing);
      await t.tap(find.text('Continuar'));
      await t.pumpAndSettle();
      expect(controller.text, 'Mi nota sin guardar');
      expect(repo.writes, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
}

import 'package:entrenaop_trainer/trainer_agenda_page.dart';
import 'package:entrenaop_trainer/trainer_program_pages.dart';
import 'package:entrenaop_trainer/trainer_program_repository.dart';
import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/guided_program_codec.dart';
import 'package:workout_editor_ui/guided_program_editor_page.dart';
import 'package:workout_editor_ui/program_session_picker.dart';

import 'trainer_workout_flow_test.dart';

const privateProgram = GuidedProgram(
  id: 'program',
  familyId: 'family',
  version: 2,
  status: 'published',
  name: 'Preparación de dominadas',
  description: 'Base y progreso',
  mode: GuidedProgramMode.phased,
  phases: [
    GuidedPhase(
      name: 'Base',
      durationWeeks: 2,
      instructions: 'Revisar RPE',
      sessions: [GuidedSession(templateId: 'template', name: 'Fuerza A')],
    ),
    GuidedPhase(
      name: 'Progresión',
      durationWeeks: 3,
      instructions: 'Comprobar técnica',
      sessions: [GuidedSession(templateId: 'template', name: 'Fuerza B')],
    ),
  ],
);

class ProgramFixture extends TrainerProgramRepository {
  bool failSave = false, failAssign = false;
  final saved =
      <({String operation, GuidedProgram program, String? previous})>[];
  final assigned =
      <
        ({
          String operation,
          String relation,
          String program,
          List<TrainerProgramEntry> entries,
          String? note,
        })
      >[];
  @override
  Future<GuidedProgram> program(String id) async => privateProgram;
  @override
  Future<List<TrainerProgram>> programs({TrainerProgram? before}) async =>
      before == null
      ? [
          TrainerProgram.fromJson({
            'id': 'program',
            'family_id': 'family',
            'version': 2,
            'status': 'published',
            'created_at': '2026-10-21T10:00:00Z',
            'content': guidedProgramToJson(privateProgram),
          }),
        ]
      : [];
  @override
  Future<String> save(
    String operationId,
    GuidedProgram program, {
    String? previousId,
  }) async {
    saved.add((operation: operationId, program: program, previous: previousId));
    if (failSave) throw StateError('Conexión incierta');
    return 'program-saved';
  }

  @override
  Future<void> assign({
    required String id,
    required String relationId,
    required String programId,
    required List<TrainerProgramEntry> entries,
    String? note,
  }) async {
    assigned.add((
      operation: id,
      relation: relationId,
      program: programId,
      entries: List.of(entries),
      note: note,
    ));
    if (failAssign) throw StateError('Conexión incierta');
  }
}

class ChangingLibraryFixture extends WorkoutFixture {
  bool retired = false;
  @override
  Future<List<TrainerWorkout>> workouts({TrainerWorkout? before}) async =>
      retired ? [] : super.workouts(before: before);
}

class AgendaFixture extends TrainerAgendaRepository {
  final calls = <({DateTime from, DateTime to, String? after})>[];
  bool paginate = false;
  TrainerAgendaItem item(int index, {int day = 21}) =>
      TrainerAgendaItem.fromJson({
        'id': 'assignment-$index',
        'template_id': 'template',
        'template_name': 'Fuerza A',
        'template_version': 1,
        'scheduled_date': '2026-10-${day.toString().padLeft(2, '0')}',
        'created_at': '2026-10-21T10:00:00Z',
        'status': 'planned',
        'execution_id': null,
        'note': 'Indicaciones privadas',
        'client_id': 'pupil',
        'client_name': 'Alumno de ensayo',
      });
  @override
  Future<List<TrainerAgendaItem>> range(
    DateTime from,
    DateTime to, {
    TrainerAgendaItem? after,
    TrainerAssignmentVisibility visibility =
        TrainerAssignmentVisibility.current,
  }) async {
    calls.add((from: from, to: to, after: after?.assignment.id));
    if (from.month != 10) return [];
    if (!paginate) return [item(0)];
    return after == null
        ? List.generate(100, (i) => item(i))
        : [item(100, day: 22)];
  }
}

Widget programApp(Widget child, {double scale = 1}) => MaterialApp(
  theme: EntrenaTheme.dark,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

Future<void> visibleTap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      maxScrolls: 80,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openProgramDialog(
  WidgetTester tester,
  ProgramFixture repo, {
  double scale = 1,
  DateTime? initialDate,
}) async {
  await tester.pumpWidget(
    programApp(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => TrainerProgramAssignmentDialog(
                repository: repo,
                relationId: 'relation',
                initialDate: initialDate,
              ),
            ),
            child: const Text('Abrir pauta'),
          ),
        ),
      ),
      scale: scale,
    ),
  );
  await tester.tap(find.text('Abrir pauta'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'la navegación lateral sigue disponible para lectores de pantalla',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        final router = GoRouter(
          initialLocation: '/programs',
          routes: [
            ShellRoute(
              builder: (_, state, child) =>
                  TrainerShell(location: state.uri.path, child: child),
              routes: [
                GoRoute(
                  path: '/programs',
                  builder: (_, _) =>
                      const Scaffold(body: Text('Biblioteca del profesional')),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
        );
        await tester.pumpAndSettle();
        for (final label in [
          'Alumnos',
          'Agenda',
          'Ejercicios',
          'Sesiones',
          'Programas',
        ]) {
          final labels = tester.semantics.simulatedAccessibilityTraversal().map(
            (node) => node.getSemanticsData().label,
          );
          expect(
            labels.any((text) => text.contains(label)),
            isTrue,
            reason: '$label debe estar disponible fuera de la ruta activa',
          );
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'revisar la biblioteca no invalida una receta elegida en el montaje actual',
    (tester) async {
      final repo = ProgramFixture();
      final workouts = ChangingLibraryFixture();
      final router = GoRouter(
        initialLocation: '/programs/new',
        routes: [
          GoRoute(
            path: '/programs',
            builder: (_, _) => const Scaffold(
              body: Text('Programa con referencia conservada'),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => TrainerProgramEditorPage(
                  repository: repo,
                  workouts: workouts,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/workouts',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () {
                  workouts.retired = true;
                  context.pop();
                },
                child: const Text('Biblioteca revisada'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('program-field-Nombre del programa')),
        'Mi montaje privado',
      );
      await visibleTap(tester, find.text('Elegir del catálogo'));
      await visibleTap(tester, find.text(privateRecipe.name));
      await visibleTap(tester, find.text('Abrir mis sesiones privadas'));
      await tester.tap(find.text('Biblioteca revisada'));
      await tester.pumpAndSettle();
      await visibleTap(tester, find.text('Guardar programa privado'));
      expect(
        repo.saved.single.program.phases.single.sessions.single.templateId,
        'template',
      );
      expect(find.text('Programa con referencia conservada'), findsOneWidget);
    },
  );

  testWidgets(
    'crear rutina privada incorpora una receta desde el selector compartido',
    (tester) async {
      final repo = ProgramFixture();
      final router = GoRouter(
        initialLocation: '/programs/new',
        routes: [
          GoRoute(
            path: '/programs',
            builder: (_, _) =>
                const Scaffold(body: Text('Biblioteca guardada')),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => TrainerProgramEditorPage(
                  repository: repo,
                  workouts: WorkoutFixture(),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('program-field-Nombre del programa')),
        'Rutina de prueba',
      );
      await visibleTap(tester, find.text('Elegir del catálogo'));
      expect(find.byType(ProgramSessionPicker), findsOneWidget);
      expect(find.text('Publicadas'), findsNothing);
      await visibleTap(tester, find.text(privateRecipe.name));
      await visibleTap(tester, find.text('Guardar programa privado'));
      expect(repo.saved.single.program.mode, GuidedProgramMode.guide);
      expect(
        repo.saved.single.program.phases.single.sessions.single.templateId,
        'template',
      );
      expect(find.text('Biblioteca guardada'), findsOneWidget);
    },
  );

  testWidgets(
    'elegir una fase pauta solo sus sesiones sin cambiar el programa',
    (tester) async {
      final repo = ProgramFixture();
      await openProgramDialog(tester, repo);
      await visibleTap(tester, find.text(privateProgram.name));
      await visibleTap(tester, find.text('Todas las fases'));
      await tester.tap(find.text('Progresión').last);
      await tester.pumpAndSettle();
      await visibleTap(tester, find.text('Confirmar 1 sesión'));
      expect(repo.assigned.single.entries.single.phase, 1);
      expect(repo.assigned.single.entries.single.session, 0);
      expect(privateProgram.phases, hasLength(2));
    },
  );

  testWidgets(
    'mover el inicio conserva días civiles y bloquea cambios al reintentar',
    (tester) async {
      final repo = ProgramFixture()..failAssign = true;
      await openProgramDialog(
        tester,
        repo,
        initialDate: DateTime(2026, 10, 24),
      );
      await visibleTap(tester, find.text(privateProgram.name));
      await visibleTap(
        tester,
        find.byKey(const ValueKey('program-shift-start')),
      );
      await tester.tap(find.text('26').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        find.text('2 sesiones · 2 fechas · 26/10/2026 – 28/10/2026'),
        findsOneWidget,
      );
      await visibleTap(tester, find.text('Confirmar 2 sesiones'));
      expect(
        repo.assigned.single.entries.map((entry) => entry.toJson()['date']),
        ['2026-10-26', '2026-10-28'],
      );
      final shift = find.byKey(const ValueKey('program-shift-start'));
      await tester.scrollUntilVisible(
        shift,
        -300,
        maxScrolls: 30,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<OutlinedButton>(shift).onPressed, isNull);
      repo.failAssign = false;
      await visibleTap(
        tester,
        find.text('Comprobar y reintentar planificación'),
      );
      expect(repo.assigned.last.operation, repo.assigned.first.operation);
      expect(
        repo.assigned.last.entries.map((entry) => entry.toJson()).toList(),
        repo.assigned.first.entries.map((entry) => entry.toJson()).toList(),
      );
    },
  );

  testWidgets(
    'el programa profesional usa el mismo creador y fija fases y versiones al reintentar',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ProgramFixture()..failSave = true;
      final workouts = WorkoutFixture();
      final router = GoRouter(
        initialLocation: '/programs/program/revise',
        routes: [
          GoRoute(
            path: '/programs',
            builder: (_, _) =>
                const Scaffold(body: Text('Programa confirmado')),
            routes: [
              GoRoute(
                path: 'program/revise',
                builder: (_, _) => TrainerProgramEditorPage(
                  repository: repo,
                  workouts: workouts,
                  programId: 'program',
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GuidedProgramEditorPage), findsOneWidget);
      expect(find.text('Categorías del programa'), findsNothing);
      expect(find.text('Guardar y revisar'), findsNothing);
      await visibleTap(tester, find.text('Guardar programa privado'));
      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.previous, 'program');
      expect(repo.saved.single.program.phases[1].durationWeeks, 3);
      expect(
        repo.saved.single.program.phases[0].sessions.single.templateId,
        'template',
      );
      expect(find.text('Comprobar y reintentar guardado'), findsOneWidget);
      repo.failSave = false;
      await visibleTap(tester, find.text('Comprobar y reintentar guardado'));
      expect(repo.saved, hasLength(2));
      expect(repo.saved[0].operation, repo.saved[1].operation);
      expect(
        guidedProgramToJson(repo.saved[0].program),
        guidedProgramToJson(repo.saved[1].program),
      );
      expect(workouts.saved, isEmpty);
      expect(find.text('Programa confirmado'), findsOneWidget);
    },
  );

  testWidgets(
    'pautar un programa reutiliza la versión y conserva toda la tanda al reintentar',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ProgramFixture()..failAssign = true;
      await openProgramDialog(tester, repo);
      await visibleTap(tester, find.text(privateProgram.name));
      await visibleTap(tester, find.text('Repetir la planificación después'));
      await tester.scrollUntilVisible(
        find.byType(TextField),
        250,
        maxScrolls: 20,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'Revisar sensaciones');
      await visibleTap(tester, find.text('Confirmar 4 sesiones'));
      expect(repo.assigned, hasLength(1));
      expect(repo.assigned.single.entries, hasLength(4));
      expect(
        repo.assigned.single.entries[2].date.isAfter(
          repo.assigned.single.entries[1].date,
        ),
        isTrue,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      repo.failAssign = false;
      await visibleTap(
        tester,
        find.text('Comprobar y reintentar planificación'),
      );
      expect(repo.assigned, hasLength(2));
      expect(repo.assigned[0].operation, repo.assigned[1].operation);
      expect(repo.assigned[1].program, 'program');
      expect(repo.assigned[1].relation, 'relation');
      expect(
        repo.assigned[1].entries.map((e) => e.toJson()).toList(),
        repo.assigned[0].entries.map((e) => e.toJson()).toList(),
      );
      expect(repo.assigned[1].note, 'Revisar sensaciones');
    },
  );

  testWidgets('agenda pagina sin ocultar que los recuentos son parciales', (
    tester,
  ) async {
    final repo = AgendaFixture()..paginate = true;
    await tester.pumpWidget(
      programApp(
        TrainerAgendaPage(repository: repo, now: DateTime(2026, 10, 21)),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls.single.from, DateTime(2026, 10, 1));
    expect(repo.calls.single.to, DateTime(2026, 10, 31));
    expect(
      find.textContaining('recuentos del calendario son parciales'),
      findsOneWidget,
    );
    await visibleTap(tester, find.byKey(const ValueKey('agenda-day-22')));
    expect(find.textContaining('entre las cargadas'), findsOneWidget);
    await visibleTap(tester, find.text('Cargar más pautas del mes'));
    expect(repo.calls.last.after, 'assignment-99');
    expect(
      find.textContaining('recuentos del calendario son parciales'),
      findsNothing,
    );
    expect(find.text('Alumno de ensayo'), findsOneWidget);
  });

  for (final width in [320.0, 1200.0]) {
    testWidgets('agenda y pauta son utilizables a $width con texto doble', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        programApp(
          TrainerAgendaPage(
            repository: AgendaFixture(),
            now: DateTime(2026, 10, 21),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await openProgramDialog(tester, ProgramFixture(), scale: 2);
      await tester.pumpAndSettle();
      await visibleTap(tester, find.text(privateProgram.name));
      await visibleTap(tester, find.text('Confirmar 2 sesiones'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'una entrada directa conserva navegación profesional y protege el borrador al salir',
    (tester) async {
      final exits = WorkflowExitRegistry();
      final router = GoRouter(
        initialLocation: '/programs/new',
        routes: [
          ShellRoute(
            builder: (_, state, child) =>
                TrainerShell(location: state.uri.path, child: child),
            routes: [
              GoRoute(
                path: '/clients',
                builder: (_, _) =>
                    const Scaffold(body: Text('Listado de alumnos')),
              ),
              GoRoute(
                path: '/programs',
                builder: (_, _) =>
                    const Scaffold(body: Text('Biblioteca profesional')),
                routes: [
                  GoRoute(
                    path: 'new',
                    onExit: (_, state) => exits.requestExit(state.pageKey),
                    builder: (_, state) => WorkflowExitScope(
                      controller: exits.controller(state.pageKey),
                      child: TrainerProgramEditorPage(
                        repository: ProgramFixture(),
                        workouts: WorkoutFixture(),
                        programId: 'program',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('program-field-Nombre del programa')),
        'Borrador cambiado',
      );
      router.go('/clients');
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin guardar?'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Borrador cambiado'), findsOneWidget);
      router.go('/clients');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir sin guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Listado de alumnos'), findsOneWidget);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('Sesiones'), findsOneWidget);
      await tester.tap(find.text('Más'));
      await tester.pumpAndSettle();
      expect(find.text('Programas'), findsOneWidget);
      expect(find.text('Ejercicios'), findsOneWidget);
      expect(find.text('Formularios'), findsOneWidget);
    },
  );
}

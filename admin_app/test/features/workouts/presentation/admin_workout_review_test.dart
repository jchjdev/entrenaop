import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';

WorkoutTemplate session({
  String name = 'Sesión revisada',
  bool empty = false,
}) => WorkoutTemplate(
  id: 's',
  name: name,
  description: null,
  estimatedDurationMinutes: null,
  version: 1,
  blocks: empty
      ? []
      : const [
          WorkoutBlock(
            id: 'b',
            name: 'Fuerza',
            format: WorkoutBlockFormat.straightSets,
            rounds: 1,
            restAfterSeconds: 0,
            items: [
              WorkoutItem(
                id: 'i',
                exerciseId: 'e',
                exerciseName: 'Sentadilla',
                sets: [
                  WorkoutSet(
                    id: 'set',
                    order: 0,
                    targetReps: 8,
                    restAfterSeconds: 90,
                  ),
                ],
              ),
            ],
          ),
        ],
);

class _Workouts extends Fake implements AdminWorkoutRepository {
  WorkoutTemplate? current = session();
  int writes = 0;
  bool listed = true, failVisibility = false;
  @override
  Future<void> setLibraryVisibility(
    String id,
    bool value, {
    required bool expected,
  }) async {
    expect(expected, listed);
    if (failVisibility) throw StateError('Sin conexión');
    listed = value;
  }

  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async => current;
  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async => [
    AdminWorkoutSummary(
      id: 's',
      name: 'Sesión revisada',
      status: 'draft',
      version: 1,
      isRunning: false,
      catalogScope: 'general',
      showInLibrary: listed,
    ),
  ];
  @override
  Future<void> publishDraft(String id) async {
    writes++;
  }
}

class _Programs extends Fake implements AdminProgramRepository {
  @override
  Future<bool> hasAccess() async => true;
}

class _Exercises extends Fake implements AdminExerciseRepository {}

Future<void> _mount(WidgetTester tester, _Workouts workouts) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = createAdminRouter(
    programs: _Programs(),
    exercises: _Exercises(),
    workouts: workouts,
    onSignOut: () {},
    initialLocation: '/sessions/s',
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la visibilidad se guarda sin publicar ni revisar la receta', (
    tester,
  ) async {
    final workouts = _Workouts();
    await _mount(tester, workouts);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(workouts.listed, isFalse);
    expect(workouts.writes, 0);
    expect(workouts.current, session());
    await tap(tester, find.text('Publicar sesión'));
    expect(find.textContaining('quedará fuera del listado'), findsOneWidget);
    await tap(tester, find.text('Cancelar'));
    expect(workouts.writes, 0);
  });

  testWidgets(
    'fallar visibilidad conserva la elección guardada y permite reintentar',
    (tester) async {
      final workouts = _Workouts()..failVisibility = true;
      await _mount(tester, workouts);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(
        find.textContaining('No se pudo cambiar la visibilidad'),
        findsOneWidget,
      );
      workouts.failVisibility = false;
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    },
  );
  testWidgets('una sesión vacía muestra el problema y bloquea publicar', (
    tester,
  ) async {
    final workouts = _Workouts()..current = session(empty: true);
    await _mount(tester, workouts);
    expect(find.text('La sesión no contiene bloques.'), findsOneWidget);
    final button = find
        .ancestor(
          of: find.text('Publicar en biblioteca general'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        )
        .first;
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(workouts.writes, 0);
  });

  testWidgets(
    'una edición concurrente sustituye la vista previa y exige revisar sin publicar',
    (tester) async {
      final workouts = _Workouts();
      await _mount(tester, workouts);
      await tap(tester, find.text('Publicar en biblioteca general'));
      workouts.current = session(name: 'Sesión cambiada');
      await tap(tester, find.text('Publicar en biblioteca general').last);
      expect(workouts.writes, 0);
      expect(
        find.textContaining('ha cambiado desde la revisión'),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.text('Sesión cambiada'), findsOneWidget);
    },
  );

  testWidgets(
    'si desaparece tras confirmar no publica y permite recuperar la lectura',
    (tester) async {
      final workouts = _Workouts();
      await _mount(tester, workouts);
      await tap(tester, find.text('Publicar en biblioteca general'));
      workouts.current = null;
      await tap(tester, find.text('Publicar en biblioteca general').last);
      expect(workouts.writes, 0);
      expect(
        find.textContaining('No se pudo cargar la sesión.'),
        findsOneWidget,
      );
      workouts.current = session();
      await tap(tester, find.text('Reintentar'));
      expect(find.text('Revisión antes de publicar'), findsOneWidget);
      expect(workouts.writes, 0);
    },
  );
}

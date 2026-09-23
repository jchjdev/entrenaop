import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';

class _FakeWorkouts implements AdminWorkoutRepository {
  CreatePersonalWorkoutInput? saved;
  String? programId;

  @override
  Future<String> createDraft(
    String programId,
    CreatePersonalWorkoutInput input,
  ) async {
    this.programId = programId;
    saved = input;
    return 'draft-id';
  }

  @override
  Future<List<AdminExercise>> listPublicExercises() async => const [
    AdminExercise(
      id: '30000000-0000-4000-8000-000000000001',
      name: 'Flexiones',
    ),
  ];

  @override
  Future<List<AdminWorkoutSummary>> listForProgram(String programId) async =>
      const [];
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  const program = AdminProgram(
    id: 'tropa',
    name: 'Tropa',
    kind: 'access',
    enabled: false,
  );

  testWidgets('agrupa cinco series iguales y guarda cinco parciales', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    final repository = _FakeWorkouts();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminWorkoutEditorPage(program: program, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_field('Nombre de la sesión'), 'Series de 200 m');
    await tester.enterText(_field('Veces'), '5');
    await tester.enterText(_field('Distancia (m)'), '200');
    await tester.enterText(_field('Ritmo (m:ss/km)'), '350');
    await tester.ensureVisible(find.text('Guardar borrador'));
    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();

    expect(repository.programId, 'tropa');
    final sets = repository.saved!.blocks.single.exercises.single.sets;
    expect(sets, hasLength(5));
    expect(sets.every((set) => set.targetValue == 200), isTrue);
    expect(sets.every((set) => set.targetPaceMinSecondsPerKm == 230), isTrue);
  });

  testWidgets('no guarda series con ritmo inválido', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    final repository = _FakeWorkouts();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminWorkoutEditorPage(program: program, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_field('Nombre de la sesión'), 'Series de 200 m');
    await tester.enterText(_field('Distancia (m)'), '200');
    await tester.enterText(_field('Ritmo (m:ss/km)'), '3:99');
    await tester.ensureVisible(find.text('Guardar borrador'));
    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();

    expect(repository.saved, isNull);
    expect(find.textContaining('Revisa repeticiones'), findsOneWidget);
  });

  testWidgets('crea un borrador de fuerza con el catálogo público', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    final repository = _FakeWorkouts();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminWorkoutEditorPage(program: program, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_field('Nombre de la sesión'), 'Fuerza base');
    await tester.tap(find.text('Fuerza convencional'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ejercicio del catálogo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flexiones').last);
    await tester.pumpAndSettle();
    await tester.enterText(_field('Cantidad'), '10');
    await tester.ensureVisible(find.text('Guardar borrador'));
    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();

    expect(repository.programId, 'tropa');
    final exercise = repository.saved!.blocks.single.exercises.single;
    expect(exercise.exerciseId, '30000000-0000-4000-8000-000000000001');
    expect(exercise.sets, hasLength(3));
    expect(exercise.sets.first.targetValue, 10);
  });
}

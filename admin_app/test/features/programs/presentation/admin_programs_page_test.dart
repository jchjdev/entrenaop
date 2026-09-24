import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_programs_page.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/exercise_draft.dart';

class _FakeExercises implements AdminExerciseRepository {
  @override
  Future<void> createOfficial(ExerciseDraft draft) async {}

  @override
  Future<List<AdminCatalogExercise>> listOfficial() async => const [];

  @override
  Future<void> updateOfficial(String id, ExerciseDraft draft) async {}
}

class _FakeRepository implements AdminProgramRepository {
  _FakeRepository({required this.allowed});

  final bool allowed;
  int listCalls = 0;
  int createCalls = 0;
  final programs = <AdminProgram>[];

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
    programs.add(
      AdminProgram(id: 'new', name: name, kind: kind, enabled: false),
    );
  }
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
  testWidgets('sin permiso no consulta ni muestra borradores', (tester) async {
    final repository = _FakeRepository(allowed: false);
    await tester.pumpWidget(
      MaterialApp(
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
      MaterialApp(
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
    await tester.tap(find.text('Crear borrador'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.programs.single.kind, 'access');
    expect(repository.programs.single.enabled, false);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Guardia Civil'), findsOneWidget);
    expect(find.text('Borrador'), findsOneWidget);
    expect(repository.listCalls, 2);
  });
}

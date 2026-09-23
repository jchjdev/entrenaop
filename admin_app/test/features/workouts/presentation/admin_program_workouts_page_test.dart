import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_program_workouts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';

class _FakeWorkouts implements AdminWorkoutRepository {
  bool published = false;
  int publishCalls = 0;

  @override
  Future<WorkoutTemplate?> getTemplateById(String templateId) async =>
      const WorkoutTemplate(
        id: 'template-1',
        name: 'Series 200 m',
        description: null,
        estimatedDurationMinutes: 8,
        version: 1,
        blocks: [
          WorkoutBlock(
            id: 'block-1',
            name: 'Carrera',
            format: WorkoutBlockFormat.running,
            rounds: 1,
            restAfterSeconds: 0,
            items: [
              WorkoutItem(
                id: 'item-1',
                exerciseId: runningExerciseId,
                exerciseName: 'Carrera',
                sets: [
                  WorkoutSet(
                    id: 'set-1',
                    order: 0,
                    targetDistanceMeters: 200,
                    targetPaceMinSecondsPerKm: 230,
                    targetPaceMaxSecondsPerKm: 230,
                    restAfterSeconds: 0,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

  @override
  Future<List<AdminWorkoutSummary>> listForProgram(String programId) async => [
    AdminWorkoutSummary(
      id: 'template-1',
      name: 'Series 200 m',
      status: published ? 'published' : 'draft',
      version: 1,
      isRunning: true,
    ),
  ];

  @override
  Future<void> publishDraft(String templateId) async {
    publishCalls++;
    published = true;
  }

  @override
  Future<String> createDraft(
    String programId,
    CreatePersonalWorkoutInput input,
  ) async => 'new-id';

  @override
  Future<List<AdminExercise>> listPublicExercises() async => const [];
}

void main() {
  testWidgets('publicar exige confirmación y vuelve a cargar el estado', (
    tester,
  ) async {
    final repository = _FakeWorkouts();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminProgramWorkoutsPage(
          program: const AdminProgram(
            id: 'tropa',
            name: 'Tropa',
            kind: 'access',
            enabled: false,
          ),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Series 200 m'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3:50/km'), findsOneWidget);
    await tester.tap(find.text('Publicar en biblioteca'));
    await tester.pumpAndSettle();
    expect(find.textContaining('visible para todos'), findsOneWidget);
    expect(repository.publishCalls, 0);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.publishCalls, 0);

    await tester.tap(find.text('Publicar en biblioteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar en biblioteca').last);
    await tester.pumpAndSettle();
    expect(repository.publishCalls, 1);
    expect(find.text('Publicado'), findsOneWidget);
    expect(find.text('Publicar en biblioteca'), findsNothing);
  });
}

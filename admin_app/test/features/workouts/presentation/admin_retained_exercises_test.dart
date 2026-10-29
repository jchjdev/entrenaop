import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_editor_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';

import '../../../helpers/admin_test_app.dart';

class _Workouts extends Fake
    implements AdminWorkoutRepository, AdminRetainedExerciseRepository {
  Set<String>? requested;

  @override
  Future<List<AdminExercise>> listPublicExercises() async => const [
    AdminExercise(id: 'active', name: 'Ejercicio activo'),
  ];

  @override
  Future<List<AdminExercise>> listRetainedExercises(Set<String> ids) async {
    requested = ids;
    return const [
      AdminExercise(
        id: 'retained',
        name: 'Dominada retirada',
        thumbnailUrl: 'https://fixture.invalid/dominada.jpg',
      ),
    ];
  }
}

void main() {
  testWidgets(
    'receta existente conserva nombre y foto retirados sin habilitar nuevas selecciones',
    (tester) async {
      final repository = _Workouts();
      const original = WorkoutTemplate(
        id: 'existing',
        name: 'Torso conservado',
        description: null,
        estimatedDurationMinutes: null,
        version: 2,
        blocks: [
          WorkoutBlock(
            id: 'block',
            name: 'Fuerza',
            format: WorkoutBlockFormat.straightSets,
            rounds: 1,
            restAfterSeconds: 0,
            items: [
              WorkoutItem(
                id: 'item',
                exerciseId: 'retained',
                exerciseName: 'Dominada retirada',
                sets: [
                  WorkoutSet(
                    id: 'set',
                    order: 0,
                    targetReps: 5,
                    restAfterSeconds: 60,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        AdminTestApp(
          home: AdminWorkoutEditorPage(
            program: null,
            repository: repository,
            originalTemplate: original,
            revisionId: original.id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final page = tester.widget<WorkoutEditorPage>(
        find.byType(WorkoutEditorPage),
      );
      final catalog = await page.loadExercises();
      expect(repository.requested, {'retained'});
      expect(
        catalog.singleWhere((exercise) => exercise.id == 'active').selectable,
        isTrue,
      );
      final retained = catalog.singleWhere(
        (exercise) => exercise.id == 'retained',
      );
      expect(retained.selectable, isFalse);
      expect(retained.name, 'Dominada retirada');
      expect(retained.thumbnailUrl, 'https://fixture.invalid/dominada.jpg');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('creador nuevo no consulta datos retirados', (tester) async {
    final repository = _Workouts();
    await tester.pumpWidget(
      AdminTestApp(
        home: AdminWorkoutEditorPage(program: null, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    final page = tester.widget<WorkoutEditorPage>(
      find.byType(WorkoutEditorPage),
    );
    final catalog = await page.loadExercises();
    expect(repository.requested, isNull);
    expect(catalog.map((exercise) => exercise.id), ['active']);
  });
}

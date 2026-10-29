import 'package:entrenaop_trainer/trainer_workout_filters.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:entrenaop_trainer/trainer_workout_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import 'trainer_workout_flow_test.dart' show WorkoutFixture;

TrainerWorkout session(
  String name,
  List<String> formats, {
  bool running = false,
}) => TrainerWorkout.fromJson({
  'id': name,
  'name': name,
  'version': 1,
  'created_at': '2026-10-29T10:00:00Z',
  'is_running': running,
  'formats': formats,
  'search_content': ['Dominadas', 'Activación y técnica'],
});

void main() {
  test('filtra el contenido real y combina formato, modalidad y búsqueda normalizada', () {
    final actual = session('Mesociclo A', ['straight_sets', 'amrap', 'tabata']);
    expect(
      matchesTrainerWorkout(actual, format: 'amrap', running: false),
      isTrue,
    );
    expect(
      matchesTrainerWorkout(
        actual,
        format: 'tabata',
        query: 'activacion dominadas',
      ),
      isTrue,
    );
    expect(matchesTrainerWorkout(actual, format: 'emom'), isFalse);
    expect(matchesTrainerWorkout(actual, running: true), isFalse);
    expect(
      matchesTrainerWorkout(
        session('Tabata en el título', ['straight_sets']),
        format: 'tabata',
      ),
      isFalse,
    );
    expect(
      matchesTrainerWorkout(
        session('Series', ['running'], running: true),
        running: true,
      ),
      isTrue,
    );
  });

  testWidgets(
    'biblioteca muestra AMRAP por contenido sin cambiar de pantalla',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = WorkoutFixture()
        ..availableWorkouts = [
          session('Mesociclo A', ['amrap']),
          session('Rodaje', ['running'], running: true),
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: TrainerWorkoutLibraryPage(
            repository: repo,
            accessRepository: FakeTrainerRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('AMRAP').last);
      await tester.pumpAndSettle();
      expect(find.text('Mesociclo A'), findsOneWidget);
      expect(find.text('Rodaje'), findsNothing);
      await tester.enterText(find.byType(TextField), 'dominadas');
      await tester.pumpAndSettle();
      expect(find.text('Mesociclo A'), findsOneWidget);
      expect(repo.assigned, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

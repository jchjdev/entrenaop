import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_editor_page.dart';
import 'package:entrenaop_admin/features/operations/presentation/admin_dashboard_page.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

import '../../../../../packages/workout_editor_ui/test/workout_editor_work_test.dart'
    as fixture;

class Workouts extends Fake implements AdminWorkoutRepository {
  @override
  Future<List<AdminExercise>> listPublicExercises() async => [];
}

class Catalog extends fixture.Works {
  @override
  Future<List<WorkoutEditorWork>> list() async => [
    for (final program in ['op', 'otra'])
      WorkoutEditorWork(
        id: program,
        origin: {'programId': program},
        revision: 1,
        state: {
          'editor': {'nameText': 'Trabajo $program'},
        },
      ),
  ];
}

void main() {
  testWidgets(
    'recuperar ADMIN restaura también el interruptor visible de sesión suelta',
    (tester) async {
      final works = fixture.Works();
      await tester.pumpWidget(
        MaterialApp(
          home: AdminWorkoutEditorPage(
            program: null,
            repository: Workouts(),
            work: works.latest,
            workRepository: works,
            initialShowInLibrary: true,
            onRecoveredSaved: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre de la sesión'),
        'Continuada',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(works.latest.state['context'], {'showInLibrary': false});
      expect(works.latest.state['editor']['nameText'], 'Continuada');
    },
  );
  testWidgets('los trabajos de una preparación no aparecen en otra', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSessionWorkList(
            repository: Catalog(),
            programId: 'op',
            onOpen: (path) async {
              opened.add(path);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trabajo op'), findsOneWidget);
    expect(find.text('Trabajo otra'), findsNothing);
    await tester.tap(find.text('Trabajo op'));
    await tester.pumpAndSettle();
    expect(opened, ['/programs/op/sessions/work/op']);
  });
}

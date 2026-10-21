import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_program_workouts_page.dart';
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
  @override
  Future<List<AdminWorkoutSummary>> listGeneral() async => const [];
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

class PendingWork extends fixture.Works {
  bool pending = false;
  @override
  Future<List<WorkoutEditorWork>> list() async => pending
      ? [
          const WorkoutEditorWork(
            id: 'pending',
            origin: {'programId': null},
            revision: 1,
            state: {
              'editor': {'nameText': 'Sin terminar y conservada'},
            },
          ),
        ]
      : [];
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
  for (final direct in [false, true]) {
    testWidgets(
      'volver del editor refresca pendientes, entrada directa $direct',
      (tester) async {
        final work = PendingWork();
        final router = GoRouter(
          initialLocation: direct ? '/sessions/new' : '/sessions',
          routes: [
            GoRoute(
              path: '/sessions',
              builder: (_, _) => AdminProgramWorkoutsPage(
                program: null,
                repository: Workouts(),
                workRepository: work,
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, _) => Scaffold(
                    body: TextButton(
                      onPressed: () {
                        work.pending = true;
                        context.pop();
                      },
                      child: const Text('Salir sin terminar'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        if (!direct) {
          expect(
            find.text('No tienes sesiones incompletas en esta consulta.'),
            findsOneWidget,
          );
          await tester.tap(find.text('Nueva sesión'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Salir sin terminar'));
        await tester.pumpAndSettle();
        expect(find.text('Sin terminar y conservada'), findsOneWidget);
        expect(
          find.text('No tienes sesiones incompletas en esta consulta.'),
          findsNothing,
        );
      },
    );
  }
}

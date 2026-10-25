import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:entrenaop_trainer/trainer_home_page.dart';
import 'package:entrenaop_trainer/trainer_clients_page.dart';
import 'package:entrenaop_trainer/trainer_agenda_page.dart';
import 'package:entrenaop_trainer/trainer_workout_pages.dart';
import 'package:entrenaop_trainer/trainer_program_pages.dart';
import 'package:entrenaop_trainer/trainer_exercise_page.dart';
import 'package:entrenaop_trainer/trainer_operations_pages.dart';
import 'package:entrenaop_trainer/trainer_form_pages.dart';
import 'package:entrenaop_trainer/trainer_assessment_pages.dart';
import 'package:entrenaop_trainer/trainer_groups_page.dart';
import 'package:entrenaop_trainer/trainer_recurrence_page.dart';
import 'package:entrenaop_trainer/trainer_media_page.dart';
import 'package:entrenaop_trainer/trainer_account_page.dart';
import 'package:entrenaop_trainer/trainer_client_directories.dart';
import 'package:workout_editor_ui/workout_editor_page.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import '../../test/helpers/performance_visual_review.dart';
import 'trainer_agenda_edit_test.dart' show AgendaEditFixture;
import 'trainer_program_flow_test.dart' show ProgramFixture;
import 'trainer_workout_flow_test.dart' show WorkoutFixture;
import 'trainer_exercise_flow_test.dart' show ExerciseFixture, entry;
import 'trainer_operations_flow_test.dart' show OperationsFixture;
import 'trainer_form_flow_test.dart' show FormFixture;
import 'trainer_assessment_flow_test.dart' show AssessmentFixture;
import 'trainer_groups_flow_test.dart' show GroupsFixture;
import 'trainer_recurrence_flow_test.dart' show RecurrenceFixture;
import 'trainer_media_pages_test.dart' show MediaFixture;
import 'trainer_security_page_test.dart' show SecurityFake;

void main() {
  setUpAll(() => loadReviewFont(always: true));
  testWidgets(
    'todas las secciones profesionales caben y mantienen navegación en escritorio',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1600, 1000);
      addTearDown(t.view.reset);
      final access = FakeTrainerRepository()
        ..active = [trainerRelation('Ana de ensayo')];
      final workouts = WorkoutFixture();
      final programs = ProgramFixture();
      final agenda = AgendaEditFixture();
      final operations = OperationsFixture();
      final pages = <String, Widget Function()>{
        '/home': () => TrainerHomePage(
          access: access,
          agenda: agenda,
          operations: operations,
          now: DateTime(2026, 10, 21),
        ),
        '/clients': () => TrainerClientsPage(repository: access),
        '/agenda': () => TrainerAgendaPage(
          repository: agenda,
          workouts: workouts,
          access: access,
          now: DateTime(2026, 10, 21),
        ),
        '/workouts': () => TrainerWorkoutLibraryPage(
          repository: workouts,
          accessRepository: access,
        ),
        '/programs': () =>
            TrainerProgramLibraryPage(repository: programs, access: access),
        '/exercises': () => TrainerExercisePage(
          repository: (ExerciseFixture()
            ..rows = [entry('Dominada prona'), entry('Sentadilla')]),
          access: access,
        ),
        '/reviews': () => TrainerReviewQueuePage(repository: operations),
        '/forms': () =>
            TrainerFormsPage(repository: FormFixture(), access: access),
        '/assessments': () => TrainerAssessmentsPage(
          repository: AssessmentFixture(),
          access: access,
        ),
        '/groups': () => TrainerGroupsPage(
          repository: GroupsFixture(),
          access: access,
          workouts: workouts,
          programs: programs,
        ),
        '/media': () => TrainerMediaPage(repository: MediaFixture()),
        '/recurrence': () => TrainerRecurrencePage(
          repository: RecurrenceFixture(),
          access: access,
          workouts: workouts,
        ),
        '/messages': () =>
            TrainerClientDirectoryPage(repository: access, reports: false),
        '/reports': () =>
            TrainerClientDirectoryPage(repository: access, reports: true),
        '/settings': () => TrainerAccountPage(
          email: 'ensayo@example.test',
          access: access,
          security: SecurityFake()..verified = true,
          onSignOut: () async {},
        ),
        '/form-editor': () =>
            TrainerFormEditorPage(repository: FormFixture(), formId: 'form'),
        '/assessment-editor': () => TrainerAssessmentEditorPage(
          repository: AssessmentFixture(),
          assessmentId: 'battery',
        ),
        '/program-editor': () => TrainerProgramEditorPage(
          repository: programs,
          workouts: workouts,
          programId: 'program',
        ),
        '/session-editor': () => TrainerWorkoutEditorPage(
          repository: workouts,
          templateId: 'template',
        ),
        '/running-editor': () => WorkoutEditorPage(
          title: 'Crear sesión de carrera',
          heading: 'Composición',
          instructions: 'Prepara los tramos de la sesión.',
          saveLabel: 'Guardar sesión privada',
          loadExercises: workouts.exercises,
          fixedRunningMode: true,
          onSave: (_) async => 'saved',
          onSaved: (_) {},
        ),
      };
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (_, state, child) => TrainerShell(
              location: state.uri.path == '/form-editor'
                  ? '/forms'
                  : state.uri.path == '/assessment-editor'
                  ? '/assessments'
                  : state.uri.path == '/program-editor'
                  ? '/programs'
                  : state.uri.path.endsWith('-editor')
                  ? '/workouts'
                  : state.uri.path,
              child: child,
            ),
            routes: [
              for (final entry in pages.entries)
                GoRoute(path: entry.key, builder: (_, _) => entry.value()),
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
      for (final path in pages.keys) {
        router.go(path);
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('trainer-nav-/clients')),
          findsOneWidget,
          reason: path,
        );
        expect(t.takeException(), isNull, reason: path);
        await capturePerformanceWidget(t, 'trainer-final-${path.substring(1)}');
      }
      router.go('/exercises');
      await t.pumpAndSettle();
      await t.tap(find.text('Crear ejercicio privado'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await capturePerformanceWidget(t, 'trainer-final-exercise-editor');
    },
  );
}

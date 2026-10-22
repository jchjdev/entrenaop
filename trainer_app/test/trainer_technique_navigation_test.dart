import 'package:entrenaop_trainer/trainer_clients_page.dart';
import 'package:entrenaop_trainer/trainer_media_page.dart';
import 'package:entrenaop_trainer/trainer_media_repository.dart';
import 'package:entrenaop_trainer/trainer_technique_page.dart';
import 'package:entrenaop_trainer/trainer_workout_pages.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import 'trainer_media_pages_test.dart' show MediaFixture;
import 'trainer_workout_flow_test.dart' show WorkoutFixture;

class TechniqueMediaFixture extends MediaFixture {
  final requested = <String>[];
  @override
  Future<List<TrainerMediaRow>> technique(String assignmentId) async {
    requested.add(assignmentId);
    return super.technique(assignmentId);
  }
}

class PagedTechniqueWorkouts extends WorkoutFixture {
  final requests = <TrainerAssignment?>[];
  @override
  Future<List<TrainerAssignment>> assignments(
    String clientId, {
    TrainerAssignment? before,
  }) async {
    requests.add(before);
    if (before != null) return super.assignments(clientId, before: before);
    return List.generate(
      50,
      (i) => TrainerAssignment.fromJson({
        'id': 'pending-$i',
        'template_id': 'template',
        'template_name': 'Pauta futura $i',
        'template_version': 1,
        'scheduled_date': '2026-10-28',
        'status': 'planned',
        'execution_id': null,
        'created_at': '2026-10-22T10:00:00Z',
      }),
    );
  }
}

void main() {
  Future<void> press(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'desde vídeos se elige alumno y sesión antes de cargar sus clips',
    (tester) async {
      final access = FakeTrainerRepository()
        ..active = [trainerRelation('Alumno de técnica')];
      final media = TechniqueMediaFixture();
      final workouts = WorkoutFixture();
      late final GoRouter router;
      router = GoRouter(
        initialLocation: '/media',
        routes: [
          GoRoute(
            path: '/media',
            builder: (context, _) => TrainerMediaPage(
              repository: media,
              onOpenTechnique: () => context.push('/clients?view=technique'),
            ),
          ),
          GoRoute(
            path: '/clients',
            builder: (context, _) => TrainerClientsPage(
              repository: access,
              techniqueMode: true,
              onOpenTechnique: (id) =>
                  context.push('/clients/$id/workouts?view=technique'),
            ),
          ),
          GoRoute(
            path: '/clients/:client/workouts',
            builder: (_, state) => TrainerClientWorkoutsPage(
              repository: workouts,
              accessRepository: access,
              clientId: state.pathParameters['client']!,
              techniqueMode: true,
            ),
          ),
          GoRoute(
            path: '/assignments/:assignment/technique',
            builder: (_, state) => TrainerTechniquePage(
              repository: media,
              assignmentId: state.pathParameters['assignment']!,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(media.requested, isEmpty);
      await press(tester, 'Consultar técnica de alumnos');
      await press(tester, 'Alumno de técnica');
      expect(media.requested, isEmpty);
      expect(find.text('Asignar sesión privada'), findsNothing);
      await press(tester, 'Ver vídeos compartidos');
      expect(media.requested, ['assignment']);
      expect(find.text('Técnica del alumno'), findsOneWidget);
      expect(find.text('Reproducir vídeo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'una página sin ejecuciones permite avanzar sin afirmar que no hay vídeos',
    (tester) async {
      final access = FakeTrainerRepository()
        ..active = [trainerRelation('Alumno de técnica')];
      final workouts = PagedTechniqueWorkouts();
      await tester.pumpWidget(
        MaterialApp(
          theme: EntrenaTheme.dark,
          home: TrainerClientWorkoutsPage(
            repository: workouts,
            accessRepository: access,
            clientId: 'person-a',
            techniqueMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('en esta página'), findsOneWidget);
      expect(find.text('Pauta futura 0'), findsNothing);
      await press(tester, 'Cargar más pautas');
      expect(workouts.requests.length, 2);
      expect(workouts.requests.last?.id, 'pending-49');
      expect(find.text('Ver vídeos compartidos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

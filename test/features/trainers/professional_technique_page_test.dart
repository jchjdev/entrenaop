import 'dart:async';

import 'package:entrenaop/features/trainers/domain/student_notice_repository.dart';
import 'package:entrenaop/features/trainers/presentation/pages/professional_technique_page.dart';
import 'package:entrenaop/features/workouts/data/services/client_technique_repository.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_execution.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';

import '../workouts/presentation/workout_technique_section_test.dart'
    show TechniqueFixture, execution;
import 'professional_hub_test.dart' show NoticeFixture;

class _Workouts extends Fake implements WorkoutRepository {
  int loads = 0;
  @override
  Future<WorkoutExecution?> getExecution(String executionId) async {
    loads++;
    return execution;
  }
}

class _Technique extends TechniqueFixture {
  int uploads = 0, clipLoads = 0;
  Future<ClientTechniqueContext?>? waiting;
  @override
  Future<ClientTechniqueContext?> context(String executionId) =>
      waiting ?? super.context(executionId);
  @override
  Future<List<ClientTechniqueClip>> clips(String assignmentId) {
    clipLoads++;
    return super.clips(assignmentId);
  }

  @override
  ExerciseVideoSource uploader(
    ClientTechniqueContext context, {
    String? executionSetId,
    ClientTechniqueClip? resume,
  }) {
    uploads++;
    return super.uploader(
      context,
      executionSetId: executionSetId,
      resume: resume,
    );
  }
}

class _TechniqueIndex extends NoticeFixture {
  final techniqueCursors = <TechniqueTarget?>[];
  TechniqueTargetPage page = TechniqueTargetPage(
    items: [
      TechniqueTarget(
        executionId: 'execution',
        sessionName: 'Pauta propia',
        startedAt: DateTime(2026, 10, 21),
      ),
    ],
    hasMore: true,
  );
  @override
  Future<TechniqueTargetPage> listTechnique({TechniqueTarget? before}) async {
    techniqueCursors.add(before);
    if (this.fail) throw StateError('Sin conexión');
    return page;
  }
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    _Workouts workouts,
    _Technique technique, {
    String owner = 'owner',
    double scale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ProfessionalTechniquePage(
        userId: owner,
        executionId: 'execution',
        workouts: workouts,
        technique: technique,
      ),
    ),
  );

  testWidgets(
    'sin pauta profesional propia no consulta resultados ni crea medios',
    (tester) async {
      final workouts = _Workouts();
      final technique = _Technique()..assigned = false;
      await mount(tester, workouts, technique);
      await tester.pumpAndSettle();
      expect(workouts.loads, 0);
      expect(technique.clipLoads, 0);
      expect(technique.uploads, 0);
      expect(find.text('Enviar vídeo de técnica'), findsNothing);
      expect(find.textContaining('no tiene un seguimiento'), findsOneWidget);
    },
  );

  testWidgets(
    'entrada propia muestra técnica sin solicitar medios y cabe en 320px texto2x',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final workouts = _Workouts();
      final technique = _Technique();
      await mount(tester, workouts, technique, scale: 2);
      await tester.pumpAndSettle();
      expect(workouts.loads, 1);
      expect(find.text('Técnica con tu preparador'), findsOneWidget);
      expect(find.text('Enviar vídeo de técnica'), findsOneWidget);
      expect(technique.uploads, 0);
      await tester.scrollUntilVisible(find.text('Ver resultados de la sesión'), 250);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cambio de cuenta descarta autorización tardía anterior', (
    tester,
  ) async {
    final waiting = Completer<ClientTechniqueContext?>();
    final old = _Technique()..waiting = waiting.future;
    final oldWorkouts = _Workouts();
    await mount(tester, oldWorkouts, old);
    final nextWorkouts = _Workouts();
    await mount(
      tester,
      nextWorkouts,
      _Technique()..assigned = false,
      owner: 'other',
    );
    await tester.pumpAndSettle();
    waiting.complete(
      ClientTechniqueContext.fromJson({
        'assignment_id': 'private-old',
        'execution_id': 'execution',
        'can_upload': true,
        'source_limit': 100,
        'duration_limit': 180,
      }),
    );
    await tester.pumpAndSettle();
    expect(oldWorkouts.loads, 0);
    expect(nextWorkouts.loads, 0);
    expect(find.text('Enviar vídeo de técnica'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'índice pagina propio y abre directamente técnica sin avisos previos',
    (tester) async {
      final repository = _TechniqueIndex();
      final router = GoRouter(
        initialLocation: '/my-trainer/technique',
        routes: [
          GoRoute(
            path: '/my-trainer/technique',
            builder: (_, _) => ProfessionalTechniqueIndexPage(
              repository: repository,
              userId: 'owner',
            ),
          ),
          GoRoute(
            path: '/my-trainer/technique/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Técnica ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      repository.page = TechniqueTargetPage(
        items: [
          TechniqueTarget(
            executionId: 'older',
            sessionName: 'Pauta anterior',
            startedAt: DateTime(2026, 10, 20),
          ),
        ],
        hasMore: false,
      );
      await tester.tap(find.text('Cargar sesiones anteriores'));
      await tester.pumpAndSettle();
      expect(repository.techniqueCursors.last?.executionId, 'execution');
      expect(find.text('Pauta anterior'), findsOneWidget);
      await tester.tap(find.text('Pauta propia'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/my-trainer/technique/execution');
      expect(find.text('Técnica execution'), findsOneWidget);
    },
  );
}

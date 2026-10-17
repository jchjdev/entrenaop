import 'package:flutter_test/flutter_test.dart';
import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:workout_core/guided_program.dart';
import 'package:workout_core/workout_template.dart';

const guidedFixture = GuidedProgram(
  id: 'program',
  familyId: 'family',
  status: 'published',
  name: 'Hipertrofia básica',
  description: 'Empuje, tirón y pierna con una estructura estable.',
  mode: GuidedProgramMode.guide,
  phases: [
    GuidedPhase(
      name: 'Entrenamiento',
      sessions: [
        GuidedSession(
          templateId: 'session',
          name: 'Push Press',
          warmupId: 'warmup',
          restPolicy: GuidedRestPolicy(minimumSeconds: 60, maximumSeconds: 180),
        ),
      ],
    ),
  ],
);
const guidedWorkoutFixture = WorkoutTemplate(
  id: 'session',
  name: 'Push Press',
  description: null,
  estimatedDurationMinutes: 40,
  version: 1,
  blocks: [
    WorkoutBlock(
      id: 'block',
      name: 'Trabajo principal',
      format: WorkoutBlockFormat.straightSets,
      rounds: 1,
      restAfterSeconds: 0,
      items: [
        WorkoutItem(
          id: 'item',
          exerciseId: 'exercise',
          exerciseName: 'Press de banca',
          sets: [
            WorkoutSet(
              id: 'set',
              order: 0,
              restAfterSeconds: 90,
              targetReps: 8,
            ),
          ],
        ),
      ],
    ),
  ],
);

class GuidedTestRepository extends Fake implements GuidedProgramRepository {
  String? owner = 'owner';
  @override
  String? get currentUserId => owner;
  bool followed = true, failFirst = false, morePages = true;
  final starts = <({String operation, bool omit, int? rest})>[];
  final events = <String>[];
  @override
  Future<List<StartedGuidedProgram>> startedPrograms() async => followed
      ? [const StartedGuidedProgram(program: guidedFixture, phaseIndex: 0)]
      : [];
  @override
  Future<GuidedCatalogPage> catalog({
    String query = '',
    GuidedProgramMode? mode,
    int page = 0,
    int pageSize = 2,
    bool followed = false,
  }) async {
    return GuidedCatalogPage(
      query.isEmpty || guidedFixture.name.contains(query)
          ? [guidedFixture]
          : [],
      hasMore: morePages && page == 0,
    );
  }

  @override
  Future<GuidedProgramDetail> detail(String id) async => GuidedProgramDetail(
    guidedFixture,
    follow: followed
        ? const GuidedFollow(id: 'follow', phaseIndex: 0, completed: false)
        : null,
  );
  @override
  Future<void> follow(String id) async {
    followed = true;
  }

  @override
  Future<void> advance(String followId, int expectedPhase) async {}
  @override
  Future<String> start({
    required String programId,
    required int phaseIndex,
    required int sessionIndex,
    required String operationId,
    required bool omitWarmup,
    int? restSeconds,
  }) async {
    events.add('start');
    starts.add((operation: operationId, omit: omitWarmup, rest: restSeconds));
    if (failFirst && starts.length == 1) throw StateError('Respuesta incierta');
    return 'execution-guided';
  }
}

class GuidedTestWorkouts extends Fake implements WorkoutRepository {
  GuidedTestWorkouts({this.events});
  final List<String>? events;
  int defaultStarts = 0;
  @override
  Future<WorkoutTemplate?> getTemplateById(String id) async =>
      guidedWorkoutFixture;
  @override
  Future<void> syncPendingMutations() async {
    events?.add('sync');
  }

  @override
  Future<String> startExecution(String id) async {
    defaultStarts++;
    return 'default-execution';
  }
}

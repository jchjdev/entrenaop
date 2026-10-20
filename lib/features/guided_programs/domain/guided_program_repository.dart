import 'package:workout_core/guided_program.dart';

class GuidedCatalogPage {
  const GuidedCatalogPage(this.items, {required this.hasMore});
  final List<GuidedProgram> items;
  final bool hasMore;
}

class GuidedFollow {
  const GuidedFollow({
    required this.id,
    required this.phaseIndex,
    required this.completed,
    this.abandoned = false,
    this.paused = false,
  });
  final String id;
  final int phaseIndex;
  final bool completed;
  final bool abandoned;
  final bool paused;
  bool get active => !completed && !abandoned && !paused;
  bool get resumable => !completed && !abandoned && paused;
}

class GuidedProgramAccess {
  const GuidedProgramAccess({
    required this.isPro,
    required this.activePrograms,
  });
  final bool isPro;
  final int activePrograms;
  int? get activeLimit => isPro ? null : 1;
}

class GuidedRun {
  const GuidedRun({
    required this.phaseIndex,
    required this.sessionIndex,
    required this.status,
    this.executionId,
  });
  final int phaseIndex, sessionIndex;
  final String status;
  final String? executionId;
}

class StartedGuidedProgram {
  const StartedGuidedProgram({required this.program, required this.phaseIndex});
  final GuidedProgram program;
  final int phaseIndex;
}

class GuidedProgramDetail {
  const GuidedProgramDetail(
    this.program, {
    this.follow,
    this.runs = const [],
    this.access,
  });
  final GuidedProgram program;
  final GuidedFollow? follow;
  final List<GuidedRun> runs;
  final GuidedProgramAccess? access;
  int get currentPhase => follow?.phaseIndex ?? 0;
  int get nextSession {
    final active = runs
        .where((r) => r.phaseIndex == currentPhase && r.status == 'in_progress')
        .firstOrNull;
    if (active != null) return active.sessionIndex;
    final recent = runs
        .where((r) => r.phaseIndex == currentPhase && r.status == 'completed')
        .firstOrNull;
    return recent == null
        ? 0
        : (recent.sessionIndex + 1) %
              program.phases[currentPhase].sessions.length;
  }
}

abstract class GuidedProgramRepository {
  String? get currentUserId;
  Future<List<StartedGuidedProgram>> startedPrograms();
  Future<List<GuidedProgramCategory>> categories();
  Future<GuidedCatalogPage> catalog({
    String query = '',
    GuidedProgramMode? mode,
    int page = 0,
    int pageSize = 2,
    bool followed = false,
    String? categoryId,
  });
  Future<GuidedProgramDetail> detail(String id);
  Future<void> follow(String id);
  Future<void> abandon(String followId);
  Future<void> setPaused(String followId, {required bool paused});
  Future<void> advance(String followId, int expectedPhase);
  Future<String> start({
    required String programId,
    required int phaseIndex,
    required int sessionIndex,
    required String operationId,
    required bool omitWarmup,
    int? restSeconds,
  });
}

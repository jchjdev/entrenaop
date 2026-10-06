import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_selection.dart';
import 'package:entrenaop/features/preparation_goal/domain/services/running_reference_reuse_policy.dart';
import 'package:entrenaop/features/preparation_goal/domain/services/running_reference_selection_policy.dart';

class RunningReferenceSelectionState {
  const RunningReferenceSelectionState({
    required this.selection,
    required this.candidate,
    required this.issues,
  });

  final RunningReferenceSelection? selection;
  final RunningReferenceCandidate? candidate;
  final List<RunningReferenceSelectionIssue> issues;

  bool get readyForPlanningInput =>
      selection != null && candidate != null && issues.isEmpty;
}

class ManageRunningReferenceSelectionUseCase {
  const ManageRunningReferenceSelectionUseCase({
    required this.loadCandidates,
    required this.loadContext,
    required this.loadSelection,
    required this.saveSelection,
    required this.clearSelection,
    required this.now,
  });

  final Future<List<RunningReferenceCandidate>> Function(String goalId)
  loadCandidates;
  final Future<RunningInitialContext?> Function({
    required String goalId,
    required String programId,
  })
  loadContext;
  final Future<RunningReferenceSelection?> Function(String goalId)
  loadSelection;
  final Future<void> Function(RunningReferenceSelection selection)
  saveSelection;
  final Future<void> Function(String goalId) clearSelection;
  final DateTime Function() now;

  Future<RunningReferenceSelectionState> current(String goalId) async {
    final selection = await loadSelection(goalId);
    if (selection == null) {
      return const RunningReferenceSelectionState(
        selection: null,
        candidate: null,
        issues: [],
      );
    }
    final candidates = await loadCandidates(goalId);
    final candidate = candidates
        .where((item) => selection.matches(item))
        .firstOrNull;
    if (candidate == null) {
      return RunningReferenceSelectionState(
        selection: selection,
        candidate: null,
        issues: const [RunningReferenceSelectionIssue.differentRecord],
      );
    }
    final context = await loadContext(
      goalId: goalId,
      programId: candidate.programId,
    );
    return RunningReferenceSelectionState(
      selection: selection,
      candidate: candidate,
      issues: const RunningReferenceSelectionPolicy().inspect(
        candidate: candidate,
        selection: selection,
        context: context,
        now: now(),
      ),
    );
  }

  Future<void> choose({
    required String goalId,
    required RunningReferenceCandidate candidate,
    required bool confirmContinuity,
  }) async {
    // Volver a leer el origen impide aceptar una marca fabricada por la vista.
    final actual = (await loadCandidates(goalId))
        .where(
          (item) =>
              item.goalId == goalId &&
              item.source == candidate.source &&
              item.recordId == candidate.recordId,
        )
        .firstOrNull;
    if (actual == null) {
      throw StateError('La marca ya no pertenece a esta preparación.');
    }
    final timestamp = now();
    final window = const RunningReferenceReusePolicy()
        .assess(measuredAt: actual.completedAt, now: timestamp)
        .window;
    if (window == RunningReferenceReuseWindow.expired ||
        window == RunningReferenceReuseWindow.futureDate) {
      throw StateError('Esta marca no está dentro del plazo de reutilización.');
    }
    final selection = RunningReferenceSelection(
      goalId: goalId,
      source: actual.source,
      recordId: actual.recordId,
      selectedAt: timestamp,
      continuityConfirmedAt:
          window == RunningReferenceReuseWindow.conditional && confirmContinuity
          ? timestamp
          : null,
    );
    if (window == RunningReferenceReuseWindow.conditional) {
      final context = await loadContext(
        goalId: goalId,
        programId: actual.programId,
      );
      final issues = const RunningReferenceSelectionPolicy().inspect(
        candidate: actual,
        selection: selection,
        context: context,
        now: timestamp,
      );
      if (issues.isNotEmpty) {
        throw StateError(
          'Actualiza el contexto, confirma continuidad y revisa las molestias antes de usar esta marca.',
        );
      }
    }
    await saveSelection(selection);
  }

  Future<void> clear(String goalId) => clearSelection(goalId);
}

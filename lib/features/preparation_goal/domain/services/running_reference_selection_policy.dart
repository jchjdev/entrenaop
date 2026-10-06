import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_selection.dart';
import 'package:entrenaop/features/preparation_goal/domain/services/running_reference_reuse_policy.dart';

enum RunningReferenceSelectionIssue {
  differentRecord,
  expired,
  futureDate,
  continuityNotConfirmed,
  missingCurrentContext,
  interruptedRunning,
  healthReview,
}

class RunningReferenceSelectionPolicy {
  const RunningReferenceSelectionPolicy();

  List<RunningReferenceSelectionIssue> inspect({
    required RunningReferenceCandidate candidate,
    required RunningReferenceSelection selection,
    required RunningInitialContext? context,
    required DateTime now,
  }) {
    final issues = <RunningReferenceSelectionIssue>[];
    if (!selection.matches(candidate)) {
      return const [RunningReferenceSelectionIssue.differentRecord];
    }
    final window = const RunningReferenceReusePolicy()
        .assess(measuredAt: candidate.completedAt, now: now)
        .window;
    if (window == RunningReferenceReuseWindow.expired) {
      issues.add(RunningReferenceSelectionIssue.expired);
    }
    if (window == RunningReferenceReuseWindow.futureDate) {
      issues.add(RunningReferenceSelectionIssue.futureDate);
    }
    if (window == RunningReferenceReuseWindow.conditional &&
        (selection.continuityConfirmedAt == null ||
            selection.continuityConfirmedAt!.isBefore(candidate.completedAt) ||
            selection.continuityConfirmedAt!.isAfter(now))) {
      issues.add(RunningReferenceSelectionIssue.continuityNotConfirmed);
    }

    if (context == null ||
        context.goalId != candidate.goalId ||
        context.programId != candidate.programId ||
        !_hasCurrentFourWeeks(context, now)) {
      issues.add(RunningReferenceSelectionIssue.missingCurrentContext);
    } else {
      if (window == RunningReferenceReuseWindow.conditional &&
          context.recentRunningWeeks.any((week) => week.runningDays == 0)) {
        issues.add(RunningReferenceSelectionIssue.interruptedRunning);
      }
      if (context.health == null ||
          context.health!.reportsPain ||
          context.health!.requiresProfessionalReview) {
        issues.add(RunningReferenceSelectionIssue.healthReview);
      }
    }
    return issues;
  }

  bool _hasCurrentFourWeeks(RunningInitialContext context, DateTime now) {
    if (context.recentRunningWeeks.length != 4) return false;
    if (context
        .inspect(now: now)
        .any(
          (issue) =>
              issue != RunningContextIssue.missingReference &&
              issue != RunningContextIssue.healthReview,
        )) {
      return false;
    }
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final lastSunday = today.subtract(Duration(days: today.weekday));
    final newestMonday = lastSunday.subtract(const Duration(days: 6));
    for (var index = 0; index < 4; index++) {
      final expected = newestMonday.subtract(Duration(days: index * 7));
      final actual = context.recentRunningWeeks[index].weekStart.toLocal();
      if (actual.year != expected.year ||
          actual.month != expected.month ||
          actual.day != expected.day) {
        return false;
      }
    }
    return context.health != null &&
        !context.collectedAt.isBefore(lastSunday) &&
        !context.health!.observedAt.isBefore(lastSunday) &&
        !context.health!.observedAt.isAfter(now) &&
        !context.collectedAt.isAfter(now);
  }
}

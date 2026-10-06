import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_selection.dart';
import 'package:entrenaop/features/preparation_goal/domain/services/running_reference_selection_policy.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/manage_running_reference_selection_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 30, 12);
  RunningReferenceCandidate candidate(DateTime date) =>
      RunningReferenceCandidate(
        goalId: 'goal',
        programId: 'fas',
        recordId: 'attempt-1',
        testId: 'run_2000_m',
        completedAt: date,
        durationSeconds: 650,
        protocolVersion: null,
        source: RunningReferenceSource.fasPeriodicAssessment,
      );
  RunningInitialContext context({
    bool pain = false,
    bool interrupted = false,
  }) => RunningInitialContext(
    goalId: 'goal',
    programId: 'fas',
    collectedAt: now,
    availableMinutesByWeekday: const {1: 45, 3: 45},
    reservedStrengthWeekdays: const {},
    recentRunningWeeks: [
      RecentRunningWeek(
        weekStart: DateTime(2026, 9, 21),
        runningDays: 2,
        runningMinutes: 60,
      ),
      RecentRunningWeek(
        weekStart: DateTime(2026, 9, 14),
        runningDays: interrupted ? 0 : 2,
        runningMinutes: interrupted ? 0 : 60,
      ),
      RecentRunningWeek(
        weekStart: DateTime(2026, 9, 7),
        runningDays: 2,
        runningMinutes: 60,
      ),
      RecentRunningWeek(
        weekStart: DateTime(2026, 8, 31),
        runningDays: 2,
        runningMinutes: 60,
      ),
    ],
    health: RunningHealthCheck(
      observedAt: now,
      reportsPain: pain,
      requiresProfessionalReview: false,
    ),
    reference: null,
  );

  test(
    'una marca reciente se elige explícitamente y sigue pidiendo contexto',
    () async {
      final mark = candidate(DateTime(2026, 9, 20));
      RunningReferenceSelection? saved;
      final service = ManageRunningReferenceSelectionUseCase(
        loadCandidates: (_) async => [mark],
        loadContext: ({required goalId, required programId}) async => null,
        loadSelection: (_) async => saved,
        saveSelection: (selection) async => saved = selection,
        clearSelection: (_) async => saved = null,
        now: () => now,
      );

      await service.choose(
        goalId: 'goal',
        candidate: mark,
        confirmContinuity: false,
      );
      expect(saved!.recordId, 'attempt-1');
      expect(saved!.continuityConfirmedAt, isNull);
      final resolved = await service.current('goal');
      expect(resolved.readyForPlanningInput, isFalse);
      expect(
        resolved.issues,
        contains(RunningReferenceSelectionIssue.missingCurrentContext),
      );
    },
  );

  test(
    'día 40 exige continuidad confirmada y cuatro semanas actuales',
    () async {
      final mark = candidate(DateTime(2026, 8, 21));
      RunningReferenceSelection? saved;
      final service = ManageRunningReferenceSelectionUseCase(
        loadCandidates: (_) async => [mark],
        loadContext: ({required goalId, required programId}) async => context(),
        loadSelection: (_) async => saved,
        saveSelection: (selection) async => saved = selection,
        clearSelection: (_) async => saved = null,
        now: () => now,
      );

      await expectLater(
        service.choose(
          goalId: 'goal',
          candidate: mark,
          confirmContinuity: false,
        ),
        throwsStateError,
      );
      expect(saved, isNull);
      await service.choose(
        goalId: 'goal',
        candidate: mark,
        confirmContinuity: true,
      );
      expect(saved!.continuityConfirmedAt, now);
      expect((await service.current('goal')).readyForPlanningInput, isTrue);
    },
  );

  test(
    'una semana sin carrera o dolor impide reutilizar una marca condicional',
    () async {
      final mark = candidate(DateTime(2026, 8, 21));
      for (final recent in [context(interrupted: true), context(pain: true)]) {
        RunningReferenceSelection? saved;
        final service = ManageRunningReferenceSelectionUseCase(
          loadCandidates: (_) async => [mark],
          loadContext: ({required goalId, required programId}) async => recent,
          loadSelection: (_) async => saved,
          saveSelection: (selection) async => saved = selection,
          clearSelection: (_) async => saved = null,
          now: () => now,
        );
        await expectLater(
          service.choose(
            goalId: 'goal',
            candidate: mark,
            confirmContinuity: true,
          ),
          throwsStateError,
        );
        expect(saved, isNull);
      }
    },
  );

  test('una selección anterior caduca y no alimenta el plan', () async {
    final mark = candidate(DateTime(2026, 8, 15));
    final saved = RunningReferenceSelection(
      goalId: 'goal',
      source: mark.source,
      recordId: mark.recordId,
      selectedAt: DateTime(2026, 8, 20),
    );
    final service = ManageRunningReferenceSelectionUseCase(
      loadCandidates: (_) async => [mark],
      loadContext: ({required goalId, required programId}) async => context(),
      loadSelection: (_) async => saved,
      saveSelection: (_) async {},
      clearSelection: (_) async {},
      now: () => now,
    );
    final resolved = await service.current('goal');
    expect(resolved.readyForPlanningInput, isFalse);
    expect(resolved.issues, contains(RunningReferenceSelectionIssue.expired));
  });

  test('rechaza un intento que no aparece en la preparación', () async {
    final mark = candidate(DateTime(2026, 9, 20));
    final different = RunningReferenceCandidate(
      goalId: 'goal',
      programId: 'fas',
      recordId: 'inventado',
      testId: mark.testId,
      completedAt: mark.completedAt,
      durationSeconds: mark.durationSeconds,
      protocolVersion: mark.protocolVersion,
      source: mark.source,
    );
    var saved = false;
    final service = ManageRunningReferenceSelectionUseCase(
      loadCandidates: (_) async => [mark],
      loadContext: ({required goalId, required programId}) async => context(),
      loadSelection: (_) async => null,
      saveSelection: (_) async => saved = true,
      clearSelection: (_) async {},
      now: () => now,
    );
    await expectLater(
      service.choose(
        goalId: 'goal',
        candidate: different,
        confirmContinuity: false,
      ),
      throwsStateError,
    );
    expect(saved, isFalse);
  });
}

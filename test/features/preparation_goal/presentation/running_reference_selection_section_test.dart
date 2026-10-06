import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/manage_running_reference_selection_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/running_reference_selection_section.dart';
import 'package:flutter/material.dart';
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
  final context = RunningInitialContext(
    goalId: 'goal',
    programId: 'fas',
    collectedAt: now,
    availableMinutesByWeekday: const {1: 45},
    reservedStrengthWeekdays: const {},
    recentRunningWeeks: [
      RecentRunningWeek(
        weekStart: DateTime(2026, 9, 21),
        runningDays: 2,
        runningMinutes: 60,
      ),
      RecentRunningWeek(
        weekStart: DateTime(2026, 9, 14),
        runningDays: 2,
        runningMinutes: 60,
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
      reportsPain: false,
      requiresProfessionalReview: false,
    ),
    reference: null,
  );

  testWidgets('día 40 pide confirmar antes de elegir la marca', (tester) async {
    bool? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RunningReferenceSelectionSection(
              goalId: 'goal',
              candidates: [candidate(DateTime(2026, 8, 21))],
              context: context,
              loadState: (_) async => const RunningReferenceSelectionState(
                selection: null,
                candidate: null,
                issues: [],
              ),
              choose:
                  ({
                    required goalId,
                    required candidate,
                    required confirmContinuity,
                  }) async {
                    confirmed = confirmContinuity;
                  },
              clear: (_) async {},
              now: () => now,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Confirmo que he seguido entrenando'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Elegir esta marca'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir esta marca'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('día 46 permanece visible sin opción de elegir', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RunningReferenceSelectionSection(
            goalId: 'goal',
            candidates: [candidate(DateTime(2026, 8, 15))],
            context: context,
            loadState: (_) async => const RunningReferenceSelectionState(
              selection: null,
              candidate: null,
              issues: [],
            ),
            choose: ({
              required goalId,
              required candidate,
              required confirmContinuity,
            }) async {},
            clear: (_) async {},
            now: () => now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fuera de plazo para fijar ritmos'), findsOneWidget);
    expect(find.text('Elegir esta marca'), findsNothing);
  });
}

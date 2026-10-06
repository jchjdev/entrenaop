import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_candidate.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_reference_selection.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/manage_running_reference_selection_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/widgets/running_week_preview_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final program in [
    PreparationProgramIds.fasPeriodicAssessment,
    'custom_2k_program',
  ]) {
    testWidgets('publica $program en la agenda existente', (tester) async {
      DateTime? requestedStart;
      var publishCalls = 0;
      final proposed = <String, dynamic>{
        'basis': 'returning',
        'outcome': 'initial',
        'phase': 'build',
        'recommendations': [
          {
            'code': 'quality_slot',
            'message': 'Disponibilidad recomendada sin cambiar tus minutos.',
          },
        ],
        'reason':
            'Dos exposiciones toleradas permiten aumentar una repetición.',
        'sessions': [
          {
            'date': '2026-10-05',
            'kind': 'controlled_quality',
            'minutes': 45,
            'name': 'Intervalos aeróbicos',
            'rpe_ceiling': 8,
            'segments': [
              {'role': 'warmup', 'seconds': 600},
              {
                'role': 'work',
                'seconds': 120,
                'pace_min': 235,
                'pace_max': 249,
                'recovery_seconds': 120,
              },
            ],
          },
          {'date': '2026-10-07', 'kind': 'easy', 'minutes': 45},
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RunningWeekPreviewSection(
                goalId: 'goal',
                programId: program,
                now: () => DateTime(2026, 9, 30),
                loadContext: ({required goalId, required programId}) async =>
                    null,
                loadSelectionState: (_) async =>
                    const RunningReferenceSelectionState(
                      selection: null,
                      candidate: null,
                      issues: [],
                    ),
                loadScheduledWorkouts: (_, _) async => [],
                calculateWeek: (_, monday) async {
                  requestedStart = monday;
                  return proposed;
                },
                publishWeek: (_, monday) async {
                  publishCalls++;
                  return {...proposed, 'decision_id': 'decision'};
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ver semana propuesta'));
      await tester.pumpAndSettle();
      expect(requestedStart, DateTime(2026, 10, 5));
      expect(find.textContaining('2 sesiones de carrera'), findsOneWidget);
      expect(find.text('Etapa: Desarrollo'), findsOneWidget);
      expect(
        find.text('Disponibilidad recomendada sin cambiar tus minutos.'),
        findsOneWidget,
      );
      expect(find.textContaining('Dos exposiciones toleradas'), findsOneWidget);
      await tester.tap(find.text('Ver tramos y orientación de esfuerzo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('3:55–4:09/km orientativo'), findsOneWidget);
      await tester.tap(find.text('Ver tramos y orientación de esfuerzo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Añadir sesiones a Mi semana'));
      await tester.tap(find.text('Añadir sesiones a Mi semana'));
      await tester.pumpAndSettle();
      expect(publishCalls, 1);
      expect(find.text('Ver en Mi semana'), findsOneWidget);
    });
  }
  testWidgets('simula la regla actual sin modificar la semana publicada', (
    tester,
  ) async {
    var replayCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RunningWeekPreviewSection(
              goalId: 'goal',
              programId: PreparationProgramIds.fasPeriodicAssessment,
              now: () => DateTime(2026, 9, 30),
              loadContext: ({required goalId, required programId}) async =>
                  null,
              loadSelectionState: (_) async =>
                  const RunningReferenceSelectionState(
                    selection: null,
                    candidate: null,
                    issues: [],
                  ),
              loadScheduledWorkouts: (_, _) async => [],
              calculateWeek: (_, _) async => {
                'decision_id': 'published-v1',
                'basis': 'recent',
                'outcome': 'initial',
                'sessions': [
                  {'date': '2026-10-05', 'kind': 'easy', 'minutes': 45},
                ],
              },
              previewInitialWeek: (_, _) async {
                replayCalls++;
                return {
                  'simulation': true,
                  'sessions': [
                    {'date': '2026-10-05', 'kind': 'easy', 'minutes': 30},
                    {'date': '2026-10-07', 'kind': 'easy', 'minutes': 30},
                  ],
                };
              },
              publishWeek: (_, _) async =>
                  throw StateError('Una simulación no debe publicar sesiones.'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ver semana propuesta'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('1 sesiones de carrera · 45 min'),
      findsOneWidget,
    );
    await tester.tap(find.text('Simular esta semana con la regla actual'));
    await tester.pumpAndSettle();
    expect(replayCalls, 1);
    expect(
      find.text('Regla actual · 2 sesiones · 60 min en total esta semana'),
      findsOneWidget,
    );
    expect(
      find.textContaining('No modifica la semana publicada'),
      findsOneWidget,
    );
    expect(
      find.textContaining('1 sesiones de carrera · 45 min'),
      findsOneWidget,
    );
  });

  testWidgets(
    'muestra la siguiente semana calculada con ejecuciones sin publicarla',
    (tester) async {
      var forecastCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RunningWeekPreviewSection(
                goalId: 'goal',
                programId: PreparationProgramIds.fasPeriodicAssessment,
                now: () => DateTime(2026, 10, 1),
                loadContext: ({required goalId, required programId}) async =>
                    null,
                loadSelectionState: (_) async =>
                    const RunningReferenceSelectionState(
                      selection: null,
                      candidate: null,
                      issues: [],
                    ),
                loadScheduledWorkouts: (_, _) async => [],
                calculateWeek: (_, _) async => {
                  'decision_id': 'published-v2',
                  'basis': 'recent',
                  'outcome': 'initial',
                  'sessions': [
                    {'date': '2026-10-05', 'kind': 'easy', 'minutes': 30},
                    {'date': '2026-10-08', 'kind': 'easy', 'minutes': 30},
                  ],
                },
                previewNextWeek: (_) async {
                  forecastCalls++;
                  return {
                    'simulation': true,
                    'week_start': '2026-10-12',
                    'outcome': 'maintain',
                    'sessions': [
                      {
                        'date': '2026-10-12',
                        'kind': 'controlled_quality',
                        'variant_code': 'controlled_5x2_v1',
                        'minutes': 36,
                      },
                      {'date': '2026-10-15', 'kind': 'easy', 'minutes': 30},
                    ],
                  };
                },
                publishWeek: (_, _) async =>
                    throw StateError('La simulación no debe publicar.'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.text('Simular la siguiente semana con mis resultados'),
      );
      await tester.pumpAndSettle();
      expect(forecastCalls, 1);
      expect(
        find.textContaining('Semana del 12/10 · 2 sesiones'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'lunes 12/10 · Calidad controlada · 5 × 2 min · 36 min',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('jueves 15/10 · Carrera fácil · 30 min'),
        findsOneWidget,
      );
      expect(
        find.textContaining('No añade ni cambia entrenamientos'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'no inventa una pauta local para un programa sin motor conectado',
    (tester) async {
      DateTime? requestedStart;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RunningWeekPreviewSection(
                goalId: 'goal',
                programId: 'program',
                now: () => DateTime(2026, 9, 30),
                loadContext: ({required goalId, required programId}) async =>
                    RunningInitialContext(
                      goalId: goalId,
                      programId: programId,
                      collectedAt: DateTime(2026, 9, 29),
                      availableMinutesByWeekday: const {2: 45, 6: 45},
                      reservedStrengthWeekdays: const {},
                      recentRunningWeeks: [
                        for (var index = 0; index < 4; index++)
                          RecentRunningWeek(
                            weekStart: DateTime(2026, 9, 21 - index * 7),
                            runningDays: 2,
                            runningMinutes: 90,
                          ),
                      ],
                      health: RunningHealthCheck(
                        observedAt: DateTime(2026, 9, 29),
                        reportsPain: false,
                        requiresProfessionalReview: false,
                      ),
                      reference: null,
                    ),
                loadSelectionState: (_) async => RunningReferenceSelectionState(
                  selection: RunningReferenceSelection(
                    goalId: 'goal',
                    source: RunningReferenceSource.programAssessment,
                    recordId: 'record',
                    selectedAt: DateTime(2026, 9, 29),
                  ),
                  candidate: RunningReferenceCandidate(
                    goalId: 'goal',
                    programId: 'program',
                    recordId: 'record',
                    testId: 'test',
                    completedAt: DateTime(2026, 9, 25),
                    durationSeconds: 600,
                    protocolVersion: 'run_2000m_v1',
                    source: RunningReferenceSource.programAssessment,
                  ),
                  issues: const [],
                ),
                loadScheduledWorkouts: (start, end) async {
                  requestedStart = start;
                  return const [];
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requestedStart, isNull);
      expect(find.textContaining('aún no está conectada'), findsOneWidget);
      expect(find.text('Ver primera semana propuesta'), findsNothing);
    },
  );
}

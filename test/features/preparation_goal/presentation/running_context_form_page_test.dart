import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_initial_context.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/running_context_form_page.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('el bloque de carrera reutiliza la disponibilidad común', (
    tester,
  ) async {
    const goal = PreparationGoal(
      id: 'goal',
      program: PreparationProgram(
        id: PreparationProgramIds.fasPeriodicAssessment,
        name: 'FAS',
        kind: PreparationProgramKind.internalAssessment,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RunningContextFormPage(
          goalId: 'goal',
          goals: const _Goals(goal),
          loadContext: ({required goalId, required programId}) async => null,
          loadSharedAvailability: () async => {1: 25, 3: 60},
          saveContext: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Disponibilidad'), findsNothing);
    expect(
      find.textContaining('Usamos los días y minutos de tu programa'),
      findsOneWidget,
    );
    expect(find.text('Ajustar días concretos o reservar fuerza'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reutiliza la duración del perfil sin inventar los días', (
    tester,
  ) async {
    const goal = PreparationGoal(
      id: 'goal-1',
      program: PreparationProgram(
        id: PreparationProgramIds.fasPeriodicAssessment,
        name: 'FAS',
        kind: PreparationProgramKind.internalAssessment,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RunningContextFormPage(
          goalId: 'goal-1',
          goals: const _Goals(goal),
          loadContext: ({required goalId, required programId}) async => null,
          saveContext: (_) async {},
          loadPreferences: () async => const TrainingPreferences(
            availableDaysPerWeek: 4,
            sessionDurationMinutes: 60,
            experience: TrainingExperience.consistent,
            equipment: {},
            requiresProfessionalReview: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final duration = tester.widget<ChoiceChip>(
      find.ancestor(of: find.text('60 min'), matching: find.byType(ChoiceChip)),
    );
    expect(duration.selected, isTrue);
    expect(
      tester
          .widget<FilterChip>(find.byKey(const Key('available-day-1')))
          .selected,
      isFalse,
    );
  });

  testWidgets('guarda cero carrera sin confundirlo con semanas sin responder', (
    tester,
  ) async {
    const goal = PreparationGoal(
      id: 'goal-1',
      program: PreparationProgram(
        id: PreparationProgramIds.armedForcesTroopEntry,
        name: 'Tropa',
        kind: PreparationProgramKind.access,
      ),
    );
    RunningInitialContext? saved;
    final router = GoRouter(
      initialLocation: '/origin',
      routes: [
        GoRoute(
          path: '/origin',
          builder: (_, _) => const Scaffold(body: Text('Mi preparación')),
        ),
        GoRoute(
          path: '/context',
          builder: (_, _) => RunningContextFormPage(
            goalId: 'goal-1',
            goals: const _Goals(goal),
            loadContext: ({required goalId, required programId}) async => null,
            saveContext: (context) async => saved = context,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final returned = router.push<bool>('/context');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('available-day-1')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('comfortable-minutes-60')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('comfortable-minutes-60')));

    for (var week = 0; week < 4; week++) {
      final days = find.byKey(Key('recent-days-$week'));
      await tester.scrollUntilVisible(
        days,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(days, '0');
      await tester.enterText(find.byKey(Key('recent-minutes-$week')), '0');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final painQuestion = find.text('¿Tienes dolor o molestias al entrenar?');
    await tester.scrollUntilVisible(
      painQuestion,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    final painNo = find.descendant(
      of: find.ancestor(of: painQuestion, matching: find.byType(Card)),
      matching: find.text('No'),
    );
    await tester.ensureVisible(painNo);
    await tester.pumpAndSettle();
    await tester.tap(painNo);
    final reviewQuestion = find.text(
      '¿Hay una lesión o limitación que requiere revisión antes de entrenar?',
    );
    await tester.scrollUntilVisible(
      reviewQuestion,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    final reviewNo = find.descendant(
      of: find.ancestor(of: reviewQuestion, matching: find.byType(Card)),
      matching: find.text('No'),
    );
    await tester.ensureVisible(reviewNo);
    await tester.pumpAndSettle();
    await tester.tap(reviewNo);
    // Cambiar de meta no debe conservar un tiempo oculto como segundo objetivo.
    final goalMode = find.byType(DropdownButtonFormField<String>);
    await tester.scrollUntilVisible(
      goalMode,
      -180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(goalMode);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alcanzar una marca de 2 km').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Meta de 2 km'),
      '7:45',
    );
    await tester.tap(goalMode);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Umbral del catálogo con margen').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Segundos por debajo del umbral'),
      '10',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Guardar datos'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar datos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar datos'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(await returned, isTrue);
    expect(router.state.uri.path, '/origin');
    expect(find.text('Mi preparación'), findsOneWidget);
    expect(saved!.availableMinutesByWeekday, {1: 45});
    expect(
      saved!.recentRunningWeeks.map((week) => week.runningDays),
      everyElement(0),
    );
    expect(
      saved!.recentRunningWeeks.map((week) => week.runningMinutes),
      everyElement(0),
    );
    expect(saved!.health!.reportsPain, isFalse);
    expect(saved!.comfortableContinuousMinutes, 60);
    expect(saved!.targetTwoKilometreSeconds, isNull);
    expect(saved!.officialMarginSeconds, 10);
    expect(
      saved!.inspect(now: DateTime.now()),
      contains(RunningContextIssue.missingReference),
    );
  });
}

class _Goals implements PreparationGoalRepository {
  const _Goals(this.goal);
  final PreparationGoal goal;

  @override
  Future<List<PreparationGoal>> getActiveGoals() async => [goal];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

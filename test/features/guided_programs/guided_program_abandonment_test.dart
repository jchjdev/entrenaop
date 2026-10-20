import 'dart:async';

import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_program_cubits.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_program_page.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_session_page.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/guided_program_fixture.dart';

void main() {
  Future<void> showProgram(WidgetTester tester, _Repository repo) async {
    final cubit = GuidedDetailCubit(repo, 'program')..load();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: EntrenaTheme.dark,
        home: BlocProvider.value(
          value: cubit,
          child: const GuidedProgramPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('dejar exige confirmar y permite reiniciar con texto $scale×', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 780));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final repo = _Repository();
      await showProgram(tester, repo);
      await tester.scrollUntilVisible(find.text('Dejar programa'), 200);
      await tester.tap(find.text('Dejar programa'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repo.abandonments, 0);
      expect(find.text('Has dejado este programa'), findsNothing);

      await tester.tap(find.text('Dejar programa'));
      await tester.pumpAndSettle();
      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Dejar programa'),
      );
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repo.abandonments, 1);
      await tester.scrollUntilVisible(
        find.text('Has dejado este programa'),
        -200,
      );
      expect(find.text('Has dejado este programa'), findsOneWidget);
      expect(find.text('Programa completado'), findsNothing);
      expect(find.text('Dejar programa'), findsNothing);
      expect(find.textContaining('Siguiente en la secuencia'), findsNothing);
      expect((await repo.detail('program')).runs.single.status, 'completed');
      expect(await repo.startedPrograms(), isEmpty);

      await tester.ensureVisible(find.text('Volver a iniciar programa'));
      await tester.tap(find.text('Volver a iniciar programa'));
      await tester.pumpAndSettle();
      expect(repo.abandoned, isFalse);
      expect(find.textContaining('Siguiente en la secuencia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'una sesión en curso conserva acceso y explica cómo dejar el programa',
    (tester) async {
      await showProgram(tester, _Repository()..running = true);
      expect(find.textContaining('En curso'), findsOneWidget);
      await tester.ensureVisible(find.text('Dejar programa'));
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Dejar programa'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text(
          'Termina o abandona la sesión en curso para dejar el programa.',
        ),
        findsOneWidget,
      );
    },
  );

  test(
    'fallar o repetir mientras guarda no retira el seguimiento local',
    () async {
      final repo = _Repository()..gate = Completer<void>();
      final cubit = GuidedDetailCubit(repo, 'program');
      addTearDown(cubit.close);
      await cubit.load();
      final pending = cubit.abandon();
      expect(cubit.state.busy, isTrue);
      await cubit.abandon();
      expect(repo.abandonments, 1);
      expect(cubit.state.detail!.follow!.active, isTrue);
      repo.gate!.completeError(
        StateError('Sesión abierta en otro dispositivo'),
      );
      await pending;
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.detail!.follow!.active, isTrue);
      expect(cubit.state.error, contains('termina o abandona'));
      repo.gate = null;
      await cubit.abandon();
      expect(cubit.state.detail!.follow!.abandoned, isTrue);
    },
  );

  testWidgets(
    'una URL de sesión de programa abandonado solo permite vista previa',
    (tester) async {
      final repo = _Repository()..abandoned = true;
      final workouts = GuidedTestWorkouts();
      await tester.pumpWidget(
        MaterialApp(
          home: GuidedSessionPage(
            repository: repo,
            workouts: workouts,
            programId: 'program',
            phaseIndex: 0,
            sessionIndex: 0,
            getTemplate: GetWorkoutTemplateUseCase(workouts),
            startDefault: StartWorkoutExecutionUseCase(workouts),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('workout-preview-start')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text(
          'Has dejado este programa. Puedes volver a iniciarlo desde su ficha.',
        ),
        findsOneWidget,
      );
      expect(repo.starts, isEmpty);
    },
  );
}

class _Repository extends GuidedTestRepository {
  bool abandoned = false, running = false;
  int abandonments = 0;
  Completer<void>? gate;
  @override
  Future<GuidedProgramDetail> detail(String id) async => GuidedProgramDetail(
    guidedFixture,
    follow: GuidedFollow(
      id: 'follow',
      phaseIndex: 0,
      completed: false,
      abandoned: abandoned,
    ),
    runs: [
      GuidedRun(
        phaseIndex: 0,
        sessionIndex: 0,
        status: running ? 'in_progress' : 'completed',
      ),
    ],
  );
  @override
  Future<List<StartedGuidedProgram>> startedPrograms() async =>
      abandoned ? [] : super.startedPrograms();
  @override
  Future<void> abandon(String followId) async {
    expect(followId, 'follow');
    abandonments++;
    await gate?.future;
    abandoned = true;
  }

  @override
  Future<void> follow(String id) async {
    abandoned = false;
  }
}

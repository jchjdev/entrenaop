import 'dart:async';

import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_program_cubits.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_program_page.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_session_page.dart';
import 'package:entrenaop/features/pro/domain/pro_access.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/guided_program_fixture.dart';

void main() {
  Future<void> showProgram(WidgetTester tester, _Repository repo) async {
    final cubit = GuidedDetailCubit(repo, 'program')..load();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider.value(
            value: cubit,
            child: const GuidedProgramPage(),
          ),
        ),
        GoRoute(
          path: '/pro',
          builder: (_, _) => const Scaffold(body: Text('Oferta Pro')),
        ),
      ],
    );
    addTearDown(cubit.close);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('pausar y retomar conserva seguimiento e historial a $scale×', (
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
      await tester.scrollUntilVisible(find.text('Pausar programa'), 200);
      await tester.ensureVisible(find.text('Pausar programa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pausar programa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(repo.changes, isEmpty);
      await tester.ensureVisible(find.text('Pausar programa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pausar programa'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Pausar'));
      await tester.tap(find.text('Pausar'));
      await tester.pumpAndSettle();
      expect(repo.changes, [true]);
      await tester.scrollUntilVisible(find.text('Retomar programa'), -200);
      expect(find.text('Programa en pausa'), findsOneWidget);
      expect(find.text('Volver a iniciar programa'), findsNothing);
      expect(find.textContaining('Siguiente en la secuencia'), findsNothing);
      expect((await repo.detail('program')).runs.single.status, 'completed');
      await tester.tap(find.text('Retomar programa'));
      await tester.pumpAndSettle();
      expect(repo.changes, [true, false]);
      expect((await repo.detail('program')).follow!.id, 'same-follow');
      expect(find.text('Programa en pausa'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Programas activos: 1/1'),
        -200,
      );
      expect(find.text('Programas activos: 1/1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'cuota al retomar explica alternativa y abre Pro sin perder progreso',
    (tester) async {
      final repo = _Repository()
        ..paused = true
        ..otherActive = true;
      await showProgram(tester, repo);
      await tester.ensureVisible(find.text('Retomar programa'));
      await tester.tap(find.text('Retomar programa'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pausa el actual'), findsOneWidget);
      expect(
        find.textContaining('Tu progreso y tus entrenamientos se conservan.'),
        findsOneWidget,
      );
      expect(repo.paused, isTrue);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Programa en pausa'), findsOneWidget);
      await tester.tap(find.text('Retomar programa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver Pro'));
      await tester.pumpAndSettle();
      expect(find.text('Oferta Pro'), findsOneWidget);
      expect(repo.paused, isTrue);
      expect(repo.starts, isEmpty);
    },
  );

  testWidgets('sesión abierta impide pausar', (tester) async {
    await showProgram(tester, _Repository()..running = true);
    await tester.ensureVisible(find.text('Pausar programa'));
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Pausar programa'),
          )
          .onPressed,
      isNull,
    );
  });

  test(
    'fallar y repetir una pausa pendiente no concede ni altera acceso local',
    () async {
      final repo = _Repository()..gate = Completer<void>();
      final cubit = GuidedDetailCubit(repo, 'program');
      addTearDown(cubit.close);
      await cubit.load();
      final pending = cubit.setPaused(true);
      await cubit.setPaused(true);
      expect(repo.changes, [true]);
      expect(cubit.state.detail!.follow!.active, isTrue);
      repo.gate!.completeError(StateError('Sin conexión'));
      await pending;
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.detail!.follow!.active, isTrue);
      expect(cubit.state.error, isNotNull);
    },
  );

  testWidgets('URL de sesión pausada solo permite vista previa', (
    tester,
  ) async {
    final repo = _Repository()..paused = true;
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
      find.text(
        'Programa en pausa. Retómalo desde su ficha para continuar entrenando.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('workout-preview-start')),
          )
          .onPressed,
      isNull,
    );
    expect(repo.starts, isEmpty);
  });

  test('código de cuota distingue programas del resto de restricciones', () {
    final denied = ProAccessDenied.fromDetails('free_guided_program_limit');
    expect(denied?.restriction, ProRestriction.guidedPrograms);
    expect(ProAccessDenied.fromDetails('desconocido'), isNull);
    const follow = GuidedFollow(
      id: 'f',
      phaseIndex: 1,
      completed: false,
      paused: true,
    );
    expect(follow.active, isFalse);
    expect(follow.resumable, isTrue);
    expect(follow.phaseIndex, 1);
  });
}

class _Repository extends GuidedTestRepository {
  bool paused = false, otherActive = false, running = false;
  final changes = <bool>[];
  Completer<void>? gate;
  @override
  Future<GuidedProgramDetail> detail(String id) async => GuidedProgramDetail(
    guidedFixture,
    follow: GuidedFollow(
      id: 'same-follow',
      phaseIndex: 0,
      completed: false,
      paused: paused,
    ),
    runs: [
      GuidedRun(
        phaseIndex: 0,
        sessionIndex: 0,
        status: running ? 'in_progress' : 'completed',
      ),
    ],
    access: GuidedProgramAccess(
      isPro: false,
      activePrograms: paused ? (otherActive ? 1 : 0) : 1,
    ),
  );
  @override
  Future<void> setPaused(String followId, {required bool paused}) async {
    expect(followId, 'same-follow');
    changes.add(paused);
    await gate?.future;
    if (!paused && otherActive) {
      throw ProAccessDenied.fromDetails('free_guided_program_limit')!;
    }
    this.paused = paused;
  }
}

import 'dart:async';

import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/core/router/app_router.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/pro/domain/pro_access.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout_preview.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/scheduled_workout_preview_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/usecases/scheduled_workout_preview_usecases.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/scheduled_workout_preview_cubit.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_cubit.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_state.dart';
import 'package:entrenaop/features/workout_schedule/presentation/pages/workout_schedule_page.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pro_access_fixture.dart';

void main() {
  tearDown(sl.reset);

  Future<AppRouter> mount(
    WidgetTester tester,
    _Auth auth,
    Map<String, _PreviewRepository> repositories,
    List<_Schedule> schedules,
    List<ScheduledWorkoutPreviewCubit> previews, {
    String path = '/plan/week?date=2026-11-05',
  }) async {
    sl.registerSingleton<ProAccessRepository>(ProAccessFixture(isPro: true));
    sl.registerFactoryParam<WorkoutScheduleCubit, DateTime, void>((day, _) {
      final schedule = _Schedule(auth.owner, day);
      schedules.add(schedule);
      return schedule;
    });
    sl.registerFactoryParam<ScheduledWorkoutPreviewCubit, String, String>((
      id,
      owner,
    ) {
      final repository = repositories[owner]!;
      final cubit = ScheduledWorkoutPreviewCubit(
        scheduledId: id,
        getPreview: GetScheduledWorkoutPreviewUseCase(repository),
        startReviewed: StartReviewedScheduledWorkoutUseCase(repository),
      )..load();
      previews.add(cubit);
      return cubit;
    });
    final router = AppRouter(auth);
    addTearDown(router.dispose);
    addTearDown(auth.close);
    router.config.go(path);
    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: auth,
        child: MaterialApp.router(
          theme: EntrenaTheme.dark,
          routerConfig: router.config,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'agenda abre la pauta exacta y vuelve con el mismo día sin comenzar',
    (tester) async {
      final repositories = {'A': _PreviewRepository('A')};
      final schedules = <_Schedule>[];
      final previews = <ScheduledWorkoutPreviewCubit>[];
      final router = await mount(
        tester,
        _Auth(),
        repositories,
        schedules,
        previews,
      );
      final original = tester.state(find.byType(WorkoutSchedulePage));
      await tester.ensureVisible(find.text('Fuerza pautada A'));
      await tester.tap(find.text('Fuerza pautada A'));
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/plan/week/session/scheduled');
      expect(find.text('Fuerza pautada A'), findsOneWidget);
      expect(find.text('Indicaciones para A'), findsOneWidget);
      expect(repositories['A']!.lookups, ['scheduled']);
      expect(repositories['A']!.starts, 0);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.config.state.uri.toString(), '/plan/week?date=2026-11-05');
      expect(tester.state(find.byType(WorkoutSchedulePage)), same(original));
      expect(schedules.single.state.selectedDay, DateTime(2026, 11, 5));
      expect(repositories['A']!.starts, 0);
      expect(previews.single.isClosed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renovar conserva la consulta y cambiar cuenta descarta pauta y respuesta tardía',
    (tester) async {
      final auth = _Auth();
      final repositories = {
        'A': _PreviewRepository('A'),
        'B': _PreviewRepository('B'),
      };
      final schedules = <_Schedule>[];
      final previews = <ScheduledWorkoutPreviewCubit>[];
      final router = await mount(
        tester,
        auth,
        repositories,
        schedules,
        previews,
        path: '/plan/week/session/scheduled?date=2026-11-05',
      );
      final original = previews.single;
      auth.loading();
      await tester.pump();
      auth.setOwner('A');
      await tester.pumpAndSettle();
      expect(previews, hasLength(1));
      expect(repositories['A']!.lookups, ['scheduled']);
      final pending = Completer<ScheduledWorkoutPreview>();
      repositories['A']!.pending = pending.future;
      final oldLoad = original.load();
      await tester.pump();
      auth.setOwner('B');
      await tester.pumpAndSettle();
      expect(original.isClosed, isTrue);
      expect(previews, hasLength(2));
      expect(find.text('Fuerza pautada A'), findsNothing);
      expect(find.text('Fuerza pautada B'), findsOneWidget);
      pending.complete(_preview('A'));
      await oldLoad;
      await tester.pumpAndSettle();
      expect(find.text('Fuerza pautada B'), findsOneWidget);
      expect(repositories['B']!.lookups, ['scheduled']);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(router.config.state.uri.path, '/plan/week');
      expect(schedules.last.owner, 'B');
      // Una entrada directa puede no materializar la agenda bajo la consulta.
      // Cualquier agenda que sí leyera la cuenta anterior debe descartarse.
      expect(
        schedules.where((schedule) => schedule.owner == 'A').every((schedule) => schedule.isClosed),
        isTrue,
      );
      expect(find.text('Fuerza pautada A'), findsNothing);
      expect(
        repositories.values.every((repository) => repository.starts == 0),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _Auth extends Cubit<AuthState> implements AuthCubit {
  _Auth() : super(_state('A'));
  String owner = 'A';
  void loading() => emit(AuthLoading());
  void setOwner(String value) {
    owner = value;
    emit(_state(value));
  }

  static AuthState _state(String owner) => AuthAuthenticated(
    user: UserEntity(
      id: owner,
      email: '$owner@example.test',
      role: 'free',
      createdAt: DateTime(2026),
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Schedule extends Cubit<WorkoutScheduleState>
    implements WorkoutScheduleCubit {
  _Schedule(this.owner, DateTime date)
    : super(
        WorkoutScheduleState(
          weekStart: date.subtract(Duration(days: date.weekday - 1)),
          selectedDay: date,
          status: WorkoutScheduleStatus.ready,
          hasLoaded: true,
          items: [_preview(owner).scheduled],
        ),
      );
  final String owner;
  @override
  Future<void> load() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PreviewRepository implements ScheduledWorkoutPreviewRepository {
  _PreviewRepository(this.owner);
  final String owner;
  final lookups = <String>[];
  int starts = 0;
  Future<ScheduledWorkoutPreview>? pending;
  @override
  Future<ScheduledWorkoutPreview> get(String id) {
    lookups.add(id);
    return pending ?? Future.value(_preview(owner));
  }

  @override
  Future<String> startReviewed(String id, String revision) async {
    starts++;
    return 'execution';
  }
}

ScheduledWorkoutPreview _preview(String owner) => ScheduledWorkoutPreview(
  scheduled: ScheduledWorkout(
    id: 'scheduled',
    templateId: 'assigned-v3',
    templateName: 'Fuerza pautada $owner',
    templateVersion: 3,
    scheduledDate: DateTime(2026, 11, 5),
    source: ScheduledWorkoutSource.coach,
    status: ScheduledWorkoutStatus.planned,
    coachNote: 'Indicaciones para $owner',
    coachName: 'Ervi',
  ),
  workout: WorkoutTemplate(
    id: 'assigned-v3',
    name: 'Fuerza pautada $owner',
    description: null,
    estimatedDurationMinutes: 45,
    version: 3,
    blocks: const [],
  ),
  revision: '$owner-v3',
);

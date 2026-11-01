// Capturas de las pantallas reales con datos ficticios y sin acceso a red.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/domain/entities/user_entity.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/auth/presentation/pages/home_page.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_workspace_scope.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/repositories/home_favorites_repository.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/profile/presentation/pages/profile_page.dart';
import 'package:entrenaop/features/training_plan/domain/entities/training_context.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_hub_page.dart';
import 'package:entrenaop/features/trainers/presentation/pages/professional_hub_page.dart';
import 'package:entrenaop/features/trainers/presentation/student_navigation.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_core/guided_program.dart';

import '../test/support/coach_workspace_fixture.dart'
    show FakeCoach, FakeSecurity, FakeMessages, FakeVideo;
import '../test/support/pro_access_fixture.dart';
import '../test/features/trainers/professional_hub_test.dart'
    show NoticeFixture, snapshot;

import 'package:entrenaop/features/trainers/domain/student_notice_repository.dart';

void main() {
  var fontsLoaded = false;
  for (final (screen, width, scale, unread, hasTrainer, location) in [
    ('inicio', 390.0, 1.0, 2, true, '/home'),
    ('sin-avisos', 390.0, 1.0, 0, true, '/home'),
    ('inicio-accesible', 320.0, 2.0, 2, true, '/home'),
    ('entrenar-planes', 390.0, 1.0, 2, true, '/plan'),
    ('entrenar-preparaciones', 390.0, 1.0, 2, true, '/plan?tab=preparations'),
    ('entrenar-disponibilidad', 390.0, 1.0, 2, true, '/plan?tab=availability'),
    ('entrenar-accesible', 320.0, 2.0, 2, true, '/plan?tab=availability'),
    ('preparador', 390.0, 1.0, 2, true, '/my-trainer'),
    ('sin-preparador', 390.0, 1.0, 0, false, '/my-trainer'),
    ('historial', 390.0, 1.0, 0, true, '/my-trainer'),
    ('perfil', 390.0, 1.0, 2, true, '/profile'),
    ('perfil-accesible', 320.0, 2.0, 2, true, '/profile'),
    ('selector-personal', 390.0, 1.0, 2, true, '/home'),
    ('selector-accesible', 320.0, 2.0, 2, true, '/home'),
  ]) {
    testWidgets('captura $screen', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (!fontsLoaded) {
        await tester.runAsync(() async {
          final fonts =
              Platform.environment['FLUTTER_FONT_DIR'] ??
              'E:/Dev/SDK/flutter/bin/cache/artifacts/material_fonts';
          for (final (family, name) in [
            ('Roboto', 'Roboto-Regular.ttf'),
            ('MaterialIcons', 'MaterialIcons-Regular.otf'),
          ]) {
            final bytes = await File('$fonts/$name').readAsBytes();
            await (FontLoader(
              family,
            )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
          }
          fontsLoaded = true;
        });
      }
      final repository = NoticeFixture()
        ..data = snapshot(
          unread: unread,
          resources: screen == 'historial' || !hasTrainer
              ? const StudentNoticeResources()
              : const StudentNoticeResources(
                  hasAssignedWorkouts: true,
                  hasForms: true,
                  hasConversations: true,
                  conversationRelationId: 'fixture',
                ),
        );
      final navigation = StudentNavigationController(
        loadSnapshot: repository.snapshot,
        loadHasRelationship: () async => hasTrainer,
      );
      await navigation.refresh();
      addTearDown(navigation.dispose);
      final cubit = DashboardCubit(getOverview: _Overview());
      await cubit.load();
      addTearDown(cubit.close);
      final auth = _Auth();
      addTearDown(auth.close);
      final guided = _Guided();
      final access = ProAccessFixture(isPro: true);
      final router = GoRouter(
        initialLocation: location,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) {
              final child = StudentNavigationScope(
                controller: navigation,
                child: AppShell(navigationShell: shell),
              );
              return screen.startsWith('selector-')
                  ? CoachWorkspaceEntry(
                      repository: FakeCoach(),
                      security: FakeSecurity(),
                      messages: FakeMessages(),
                      video: FakeVideo(),
                      child: child,
                    )
                  : child;
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home',
                    builder: (_, _) => BlocProvider.value(
                      value: cubit,
                      child: HomePage(
                        favoritesRepository: _Favorites(),
                        userId: 'fixture',
                        guidedPrograms: guided,
                      ),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/plan',
                    builder: (_, state) => BlocProvider.value(
                      value: cubit,
                      child: TrainingHubPage(
                        loadProAccess: access.load,
                        guidedPrograms: guided,
                        initialSection: state.uri.queryParameters['tab'],
                        selectedDate: DateTime(2026, 11, 1),
                      ),
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/library',
                    builder: (_, _) => const Scaffold(),
                  ),
                ],
              ),
              StatefulShellBranch(
                initialLocation: '/profile',
                routes: [
                  GoRoute(
                    path: '/profile',
                    builder: (_, _) =>
                        ProfilePage(birthDateRepository: _BirthDate()),
                  ),
                  GoRoute(
                    path: '/assessment/history',
                    builder: (_, _) => const Scaffold(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/my-trainer',
                    builder: (_, _) => ProfessionalHubPage(
                      repository: repository,
                      userId: 'fixture',
                    ),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(path: '/coach', builder: (_, _) => const Scaffold()),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: BlocProvider<AuthCubit>.value(
            value: auth,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: EntrenaTheme.dark,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (find.byType(HomePage).evaluate().isNotEmpty) {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(
              'assets/branding/entrenaop_wordmark_on_dark.png',
              package: 'entrena_ui',
            ),
            tester.element(find.byType(HomePage)),
          ),
        );
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .map((destination) => (destination as NavigationDestination).label),
        ['Inicio', 'Entrenar', 'Biblioteca', 'Preparador', 'Perfil'],
      );
      expect(find.byTooltip('Mi perfil'), findsNothing);
      expect(find.byTooltip('$unread avisos sin leer'), findsNothing);
      await _capture(tester, boundary, screen);
      if (screen == 'entrenar-accesible') {
        await tester.ensureVisible(
          find.text('Editar disponibilidad y material'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _capture(tester, boundary, '$screen-acciones');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _Overview implements GetPreparationOverviewUseCase {
  @override
  Future<PreparationOverview> call() async {
    final today = DateUtils.dateOnly(DateTime.now());
    return PreparationOverview(
      assessments: const [],
      preferences: null,
      goals: const [
        PreparationGoal(
          id: 'fas',
          program: PreparationProgram(
            id: PreparationProgramIds.fasPeriodicAssessment,
            name: 'Mejora FAS',
            kind: PreparationProgramKind.internalAssessment,
          ),
        ),
        PreparationGoal(
          id: 'tropa',
          program: PreparationProgram(
            id: PreparationProgramIds.armedForcesTroopEntry,
            name: 'Ingreso a Tropa y Marinería',
            kind: PreparationProgramKind.access,
          ),
        ),
      ],
      programs: const [
        AdaptiveProgramProgress(
          goalId: 'fas',
          name: 'Mejora FAS',
          status: 'training',
          message: 'Tu programa y tus sesiones se conservan.',
        ),
      ],
      trainingContext: TrainingContext(
        availability: const {'1': 75, '2': 75, '3': 75, '4': 60, '5': 60},
        equipment: const {
          'dumbbell_pair',
          'kettlebell',
          'pull_up_bar',
          'cones',
        },
        reportsPain: false,
        capacityConfirmed: true,
      ),
      weekStart: today.subtract(Duration(days: today.weekday - 1)),
      weeklyWorkouts: [
        ScheduledWorkout(
          id: 'fixture',
          templateId: 'fixture',
          templateName: 'Fuerza del preparador',
          templateVersion: 1,
          scheduledDate: today,
          source: ScheduledWorkoutSource.coach,
          status: ScheduledWorkoutStatus.planned,
        ),
      ],
    );
  }
}

class _Favorites implements HomeFavoritesRepository {
  @override
  Future<List<HomeShortcut>> load(String userId) async => [];
  @override
  Future<void> save(String userId, List<HomeShortcut> favorites) async {}
}

Future<void> _capture(WidgetTester tester, GlobalKey boundary, String name) =>
    tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'docs/visual-audit/athlete-navigation-2026-11-01/$name.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });

class _Auth extends Cubit<AuthState> implements AuthCubit {
  _Auth()
    : super(
        AuthAuthenticated(
          user: UserEntity(
            id: 'fixture',
            fullName: 'Javier',
            email: 'deportista@example.test',
            role: 'user',
            createdAt: DateTime(2026, 10, 1),
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BirthDate implements ProfileBirthDateRepository {
  @override
  Future<DateTime?> get() async => DateTime(1992, 6, 15);

  @override
  Future<void> save(DateTime birthDate) async {}
}

class _Guided implements GuidedProgramRepository {
  @override
  Future<GuidedCatalogPage> catalog({
    String query = '',
    GuidedProgramMode? mode,
    int page = 0,
    int pageSize = 2,
    bool followed = false,
    String? categoryId,
  }) async => GuidedCatalogPage(
    (await startedPrograms()).map((item) => item.program).toList(),
    hasMore: false,
  );

  @override
  String? get currentUserId => 'fixture';

  @override
  Future<List<StartedGuidedProgram>> startedPrograms() async => const [
    StartedGuidedProgram(
      phaseIndex: 0,
      program: GuidedProgram(
        id: 'guided',
        name: 'Fuerza básica',
        mode: GuidedProgramMode.phased,
        phases: [
          GuidedPhase(
            name: 'Base y técnica',
            durationWeeks: 3,
            sessions: [GuidedSession(templateId: 'session', name: 'Fuerza')],
          ),
          GuidedPhase(
            name: 'Progresión',
            durationWeeks: 4,
            sessions: [GuidedSession(templateId: 'session', name: 'Fuerza')],
          ),
        ],
      ),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

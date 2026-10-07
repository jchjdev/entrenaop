import 'dart:async';

import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/features/plan_preview/presentation/pro_preview_gate.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_program_page.dart';
import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/auth/presentation/pages/home_page.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_tools_section.dart';
import 'package:entrenaop/features/auth/presentation/pages/login_page.dart';
import 'package:entrenaop/features/auth/presentation/pages/sign_up_page.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/exercises/domain/usecases/create_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/exercises/presentation/bloc/exercise_library_cubit.dart';
import 'package:entrenaop/features/exercises/presentation/pages/exercise_library_page.dart';
import 'package:entrenaop/features/library/presentation/library_hub_page.dart';
import 'package:entrenaop/features/exercises/presentation/pages/personal_exercise_creator_page.dart';
import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/initial_assessment_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/physical_assessment_history_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_assessment_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_calculator_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_history_page.dart';
import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/profile/presentation/pages/profile_page.dart';
import 'package:entrenaop/features/profile/data/profile_birth_date_repository.dart';
import 'package:entrenaop/features/program_assessment/data/program_assessment_repository.dart';
import 'package:entrenaop/features/program_assessment/presentation/program_assessment_page.dart';
import 'package:entrenaop/features/running_tools/presentation/pages/running_pace_calculator_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_detail_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/running_intake_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/running_context_form_page.dart';
import 'package:entrenaop/features/preparation_goal/data/repositories/running_intake_context_repository.dart';
import 'package:entrenaop/features/preparation_goal/data/repositories/running_week_plan_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/usecases/manage_running_reference_selection_usecase.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_goal_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/running_test_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/running_week_simulator_page.dart';
import 'package:entrenaop/features/preparation_goal/data/repositories/running_test_repository.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_goal_repository.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_hub_page.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_context_repository.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_context_page.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_cubit.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:entrenaop/features/workout_schedule/presentation/pages/workout_schedule_page.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_history_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_editor_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_library_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/active_workout_page.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_history_detail_page.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_history_page.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_editor_page.dart';
import 'package:entrenaop/features/workouts/presentation/pages/running_workout_editor_page.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_library_page.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_preview_page.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:flutter/material.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_training_page.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class RouterNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  RouterNotifier(AuthCubit authCubit) {
    _subscription = authCubit.stream.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

class AppRouter {
  final RouterNotifier _notifier;
  late final GoRouter config;
  final _rootNavigatorKey = GlobalKey<NavigatorState>();
  final _workflowExits = WorkflowExitRegistry();

  AppRouter(AuthCubit authCubit) : _notifier = RouterNotifier(authCubit) {
    // Hace que `push` actualice también la URL web. Sin esta opción la pantalla
    // cambiaba, pero el navegador seguía mostrando /home.
    GoRouter.optionURLReflectsImperativeAPIs = true;
    config = GoRouter(
      navigatorKey: _rootNavigatorKey,
      refreshListenable: _notifier,
      redirect: (context, state) {
        final authState = authCubit.state;
        final isAuthenticated = authState is AuthAuthenticated;
        final isLoading = authState is AuthLoading || authState is AuthInitial;
        final isPublicRoute =
            state.matchedLocation == '/' || state.matchedLocation == '/sign-up';

        if (isLoading) return null;
        if (!isAuthenticated && !isPublicRoute) return '/';
        if (isAuthenticated && isPublicRoute) return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/sign-up',
          builder: (context, state) => const SignUpPage(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) {
                    final auth = authCubit.state;
                    if (auth is! AuthAuthenticated) {
                      return const SizedBox.shrink();
                    }
                    return BlocProvider(
                      key: ValueKey('home-${auth.user.id}'),
                      create: (_) => sl<DashboardCubit>(),
                      child: HomePage(
                        favoritesRepository: sl(),
                        userId: auth.user.id,
                      ),
                    );
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/plan',
                  builder: (context, state) =>
                      BlocBuilder<AuthCubit, AuthState>(
                        bloc: authCubit,
                        builder: (context, auth) {
                          if (auth is! AuthAuthenticated) {
                            return const SizedBox.shrink();
                          }
                          return TrainingHubEntry(
                            key: ValueKey('plan-${auth.user.id}'),
                            createCubit: () => sl<DashboardCubit>(),
                          );
                        },
                      ),
                  routes: [
                    GoRoute(
                      path: 'pro',
                      builder: (context, state) => const ProPreviewPage(),
                    ),
                    GoRoute(
                      path: 'program/:programId',
                      builder: (context, state) => BlocProvider(
                        key: ValueKey(
                          'program-${state.pathParameters['programId']}',
                        ),
                        create: (_) => sl<PreparationGoalCubit>(),
                        child: PreparationProgramPage(
                          programId: state.pathParameters['programId']!,
                        ),
                      ),
                    ),
                    GoRoute(
                      path: 'week',
                      builder: (context, state) => BlocProvider(
                        create: (_) => sl<WorkoutScheduleCubit>(
                          param1:
                              DateTime.tryParse(
                                state.uri.queryParameters['date'] ?? '',
                              ) ??
                              DateTime.now(),
                        ),
                        child: WorkoutSchedulePage(
                          focusedWorkoutId:
                              state.uri.queryParameters['session'],
                        ),
                      ),
                      routes: [
                        _workflowRoute(
                          path: 'active/:executionId',
                          builder: (context, state) => BlocProvider(
                            create: (_) => sl<ActiveWorkoutCubit>(
                              param1: state.pathParameters['executionId']!,
                            ),
                            child: ActiveWorkoutPage(
                              timerStore: sl(),
                              cueService: sl(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'preferences',
                      redirect: (context, state) => '/profile/preferences',
                    ),
                    GoRoute(
                      path: 'goal',
                      builder: (context, state) => BlocProvider(
                        create: (_) => sl<PreparationGoalCubit>(),
                        child: PreparationGoalPage(
                          trainingWeek: DateTime.tryParse(
                            state.uri.queryParameters['week'] ?? '',
                          ),
                        ),
                      ),
                      routes: [
                        GoRoute(
                          path: ':goalId',
                          builder: (context, state) => BlocProvider(
                            // Una ruta parametrizada puede reutilizar su página.
                            // El controlador debe pertenecer a la preparación abierta.
                            key: ValueKey(
                              'detail-${state.pathParameters['goalId']}',
                            ),
                            create: (_) => sl<PreparationDetailCubit>(
                              param1: state.pathParameters['goalId']!,
                            ),
                            child: PreparationDetailPage(
                              hasRunningContext: (goalId, programId) async =>
                                  await sl<RunningIntakeContextRepository>()
                                      .get(
                                        goalId: goalId,
                                        programId: programId,
                                      ) !=
                                  null,
                              saveTargetDate: (goal, date) async {
                                await sl<PreparationGoalRepository>().save(
                                  PreparationGoal(
                                    id: goal.id,
                                    program: goal.program,
                                    targetDate: date,
                                  ),
                                );
                              },
                            ),
                          ),
                          routes: [
                            _workflowRoute(
                              path: 'training',
                              builder: (context, state) => ProPreviewGate(
                                builder: (context) => PreparationTrainingPage(
                                  key: ValueKey(
                                    'training-${state.pathParameters['goalId']}',
                                  ),
                                  goalId: state.pathParameters['goalId']!,
                                  runningStepBuilder: (context, next, back) => BlocProvider(
                                    key: ValueKey(
                                      'training-running-${state.pathParameters['goalId']}',
                                    ),
                                    create: (_) => sl<PreparationDetailCubit>(
                                      param1: state.pathParameters['goalId']!,
                                    ),
                                    child: RunningIntakePage(
                                      dataOnly: true,
                                      embedded: true,
                                      onContinue: next,
                                      onBack: back,
                                      loadContext:
                                          sl<RunningIntakeContextRepository>()
                                              .get,
                                      loadSelectionState:
                                          sl<ManageRunningReferenceSelectionUseCase>()
                                              .current,
                                      chooseReference:
                                          sl<ManageRunningReferenceSelectionUseCase>()
                                              .choose,
                                      clearReference:
                                          sl<ManageRunningReferenceSelectionUseCase>()
                                              .clear,
                                      loadScheduledWorkouts:
                                          sl<WorkoutScheduleRepository>()
                                              .getRange,
                                    ),
                                  ),
                                  repository:
                                      sl<PreparationTrainingRepository>(),
                                  initialWeek: DateTime.tryParse(
                                    state.uri.queryParameters['week'] ?? '',
                                  ),
                                ),
                              ),
                            ),
                            _workflowRoute(
                              path: 'running-intake',
                              redirect: (context, state) =>
                                  state.uri.queryParameters['dataOnly'] ==
                                      'true'
                                  ? null
                                  : '/plan/goal/${state.pathParameters['goalId']}/training',
                              builder: (context, state) => ProPreviewGate(
                                builder: (context) => BlocProvider(
                                  key: ValueKey(
                                    'running-intake-${state.pathParameters['goalId']}',
                                  ),
                                  create: (_) => sl<PreparationDetailCubit>(
                                    param1: state.pathParameters['goalId']!,
                                  ),
                                  child: RunningIntakePage(
                                    dataOnly:
                                        state.uri.queryParameters['dataOnly'] ==
                                        'true',
                                    loadContext:
                                        sl<RunningIntakeContextRepository>()
                                            .get,
                                    loadSelectionState:
                                        sl<ManageRunningReferenceSelectionUseCase>()
                                            .current,
                                    chooseReference:
                                        sl<ManageRunningReferenceSelectionUseCase>()
                                            .choose,
                                    clearReference:
                                        sl<ManageRunningReferenceSelectionUseCase>()
                                            .clear,
                                    loadScheduledWorkouts:
                                        sl<WorkoutScheduleRepository>()
                                            .getRange,
                                    calculateWeek:
                                        sl<RunningWeekPlanRepository>()
                                            .calculate,
                                    previewInitialWeek:
                                        sl<RunningWeekPlanRepository>()
                                            .previewInitialWithCurrentPolicy,
                                    previewNextWeek:
                                        sl<RunningWeekPlanRepository>()
                                            .previewNextFromCompletedWeek,
                                    publishWeek:
                                        sl<RunningWeekPlanRepository>().publish,
                                    loadPublishedWeeks:
                                        sl<RunningWeekPlanRepository>()
                                            .publishedWeeks,
                                    resetPlan:
                                        sl<RunningWeekPlanRepository>().reset,
                                  ),
                                ),
                              ),
                            ),
                            _workflowRoute(
                              path: 'running-context',
                              builder: (context, state) => RunningContextFormPage(
                                key: ValueKey(
                                  'running-context-${state.pathParameters['goalId']}',
                                ),
                                loadSharedAvailability:
                                    state.uri.queryParameters['program'] !=
                                        'true'
                                    ? null
                                    : () async {
                                        final settings =
                                            await sl<
                                                  TrainingContextRepository
                                                >()
                                                .load();
                                        return settings.context?.availability
                                                .map(
                                                  (key, minutes) => MapEntry(
                                                    int.parse(key),
                                                    minutes,
                                                  ),
                                                ) ??
                                            <int, int>{};
                                      },
                                goalId: state.pathParameters['goalId']!,
                                goals: sl<PreparationGoalRepository>(),
                                loadContext:
                                    sl<RunningIntakeContextRepository>().get,
                                saveContext:
                                    sl<RunningIntakeContextRepository>().save,
                                loadPreferences:
                                    sl<TrainingPreferencesRepository>().get,
                              ),
                            ),
                            _workflowRoute(
                              path: 'troop-assessment',
                              builder: (context, state) => BlocProvider(
                                create: (_) => sl<PhysicalAssessmentCubit>(),
                                child: InitialAssessmentPage(
                                  goalId: state.pathParameters['goalId']!,
                                ),
                              ),
                            ),
                            _workflowRoute(
                              path: 'program-assessment',
                              builder: (context, state) =>
                                  ProgramAssessmentPage(
                                    goalId: state.pathParameters['goalId']!,
                                    loadGoal: (goalId) async =>
                                        (await sl<PreparationGoalRepository>()
                                                .getActiveGoals())
                                            .where((goal) => goal.id == goalId)
                                            .firstOrNull,
                                    repository:
                                        sl<ProgramAssessmentRepository>(),
                                    loadBirthDate:
                                        sl<ProfileBirthDateRepository>().get,
                                    saveBirthDate:
                                        sl<ProfileBirthDateRepository>().save,
                                  ),
                            ),
                            _workflowRoute(
                              path: 'periodic-assessment',
                              builder: (context, state) =>
                                  FasPeriodicAssessmentPage(
                                    goalId: state.pathParameters['goalId']!,
                                    repository:
                                        sl<FasPeriodicAssessmentRepository>(),
                                    birthDateRepository: sl(),
                                  ),
                            ),
                            GoRoute(
                              path: 'week-simulator',
                              builder: (context, state) => ProPreviewGate(
                                builder: (context) => RunningWeekSimulatorPage(
                                  goalId: state.pathParameters['goalId']!,
                                  loadRunningTests:
                                      sl<RunningTestRepository>().history,
                                  loadPreferences:
                                      sl<TrainingPreferencesRepository>().get,
                                ),
                              ),
                            ),
                            GoRoute(
                              path: 'running-test',
                              builder: (context, state) => RunningTestPage(
                                goalId: state.pathParameters['goalId']!,
                                repository: sl(),
                              ),
                              routes: [
                                _workflowRoute(
                                  path: 'new',
                                  builder: (context, state) =>
                                      RunningTestFormPage(
                                        goalId: state.pathParameters['goalId']!,
                                        repository: sl(),
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            // Biblioteca reúne contenido; Mi plan conserva la prescripción.
            // Las URLs de sesiones se mantienen para no romper enlaces existentes.
            StatefulShellBranch(
              initialLocation: '/library',
              routes: [
                GoRoute(
                  path: '/library',
                  builder: (context, state) => const LibraryHubPage(),
                  routes: [
                    GoRoute(
                      path: 'exercises',
                      builder: (context, state) {
                        final auth = authCubit.state;
                        if (auth is! AuthAuthenticated) {
                          return const SizedBox.shrink();
                        }
                        final personal =
                            state.uri.queryParameters['tab'] == 'personal';
                        return BlocProvider(
                          key: ValueKey('exercises-${auth.user.id}-$personal'),
                          create: (_) => ExerciseLibraryCubit(
                            getExercises: sl<GetExercisesUseCase>(),
                            userId: auth.user.id,
                          )..load(),
                          child: ExerciseLibraryPage(
                            initialPersonalTab: personal,
                          ),
                        );
                      },
                      routes: [
                        _workflowRoute(
                          path: 'new',
                          builder: (context, state) =>
                              PersonalExerciseCreatorPage(
                                createExercise: sl<CreateExerciseUseCase>(),
                                returnOnSave: true,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: '/plan/starter-session',
                  builder: (context, state) => BlocProvider(
                    create: (_) => sl<WorkoutPreviewCubit>(
                      param1: GetStarterWorkoutUseCase.starterTemplateId,
                    ),
                    child: const WorkoutPreviewPage(
                      routeBase: '/plan/starter-session',
                    ),
                  ),
                  routes: [
                    _workflowRoute(
                      path: 'active/:executionId',
                      builder: (context, state) => BlocProvider(
                        create: (_) => sl<ActiveWorkoutCubit>(
                          param1: state.pathParameters['executionId']!,
                        ),
                        child: ActiveWorkoutPage(
                          timerStore: sl(),
                          cueService: sl(),
                        ),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: '/plan/library',
                  builder: (context, state) => BlocProvider(
                    create: (_) => sl<WorkoutLibraryCubit>(),
                    child: WorkoutLibraryPage(
                      key: ValueKey(state.uri.queryParameters['tab']),
                      initialPersonalTab:
                          state.uri.queryParameters['tab'] == 'personal',
                    ),
                  ),
                  routes: [
                    _workflowRoute(
                      path: 'new',
                      builder: (context, state) => BlocProvider(
                        create: (_) => sl<WorkoutEditorCubit>(param1: ''),
                        child: const WorkoutEditorPage(),
                      ),
                    ),
                    _workflowRoute(
                      path: 'new-running',
                      builder: (context, state) => BlocProvider(
                        create: (_) =>
                            sl<WorkoutEditorCubit>(param1: ':running'),
                        child: const RunningWorkoutEditorPage(),
                      ),
                    ),
                    GoRoute(
                      path: ':templateId',
                      builder: (context, state) {
                        final templateId = state.pathParameters['templateId']!;
                        return BlocProvider(
                          create: (_) =>
                              sl<WorkoutPreviewCubit>(param1: templateId),
                          child: WorkoutPreviewPage(
                            routeBase: '/plan/library/$templateId',
                          ),
                        );
                      },
                      routes: [
                        _workflowRoute(
                          path: 'edit',
                          builder: (context, state) => BlocProvider(
                            create: (_) => sl<WorkoutEditorCubit>(
                              param1: state.pathParameters['templateId']!,
                            ),
                            child: const WorkoutEditorPage(),
                          ),
                        ),
                        _workflowRoute(
                          path: 'edit-running',
                          builder: (context, state) => BlocProvider(
                            create: (_) => sl<WorkoutEditorCubit>(
                              param1:
                                  'running:${state.pathParameters['templateId']!}',
                            ),
                            child: const RunningWorkoutEditorPage(),
                          ),
                        ),
                        _workflowRoute(
                          path: 'active/:executionId',
                          builder: (context, state) => BlocProvider(
                            create: (_) => sl<ActiveWorkoutCubit>(
                              param1: state.pathParameters['executionId']!,
                            ),
                            child: ActiveWorkoutPage(
                              timerStore: sl(),
                              cueService: sl(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/assessment/history',
                  builder: (context, state) => BlocProvider(
                    create: (_) => sl<WorkoutHistoryCubit>(),
                    child: WorkoutHistoryPage(
                      loadPreparations:
                          sl<PreparationGoalRepository>().getActiveGoals,
                    ),
                  ),
                  routes: [
                    GoRoute(
                      path: 'physical',
                      builder: (context, state) => BlocProvider(
                        create: (_) => sl<PhysicalAssessmentHistoryCubit>(),
                        child: const PhysicalAssessmentHistoryPage(),
                      ),
                    ),
                    GoRoute(
                      path: 'workouts/:executionId',
                      builder: (context, state) => BlocProvider(
                        create: (_) => sl<WorkoutHistoryDetailCubit>(
                          param1: state.pathParameters['executionId']!,
                        ),
                        child: const WorkoutHistoryDetailPage(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => ProfilePage(
                    preparations: sl(),
                    birthDateRepository: sl(),
                  ),
                  routes: [
                    _workflowRoute(
                      path: 'preferences',
                      builder: (context, state) => TrainingContextPage(
                        repository: sl<TrainingContextRepository>(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/assessment/fas-calculator',
          builder: (context, state) => FasPeriodicCalculatorPage(
            birthDateRepository: sl(),
            repository: sl(),
          ),
        ),
        GoRoute(
          path: '/tools/running-pace-calculator',
          builder: (context, state) => const RunningPaceCalculatorPage(),
        ),
        GoRoute(
          path: '/tools',
          builder: (context, state) => const HomeToolsPage(),
        ),
        _workflowRoute(
          path: '/exercises/new',
          builder: (context, state) => PersonalExerciseCreatorPage(
            createExercise: sl<CreateExerciseUseCase>(),
          ),
        ),
        GoRoute(
          path: '/assessment/fas-history',
          builder: (context, state) => FasPeriodicHistoryPage(repository: sl()),
        ),
      ],
    );
  }

  GoRoute _workflowRoute({
    required String path,
    required GoRouterWidgetBuilder builder,
    GoRouterRedirect? redirect,
    List<RouteBase> routes = const [],
  }) => GoRoute(
    path: path,
    parentNavigatorKey: _rootNavigatorKey,
    redirect: redirect,
    routes: routes,
    onExit: (context, state) => _workflowExits.requestExit(state.pageKey),
    builder: (context, state) => WorkflowExitScope(
      controller: _workflowExits.controller(state.pageKey),
      child: builder(context, state),
    ),
  );

  void dispose() {
    config.dispose();
    _notifier.dispose();
  }
}

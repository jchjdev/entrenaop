import 'dart:async';

import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/auth/presentation/pages/home_page.dart';
import 'package:entrenaop/features/auth/presentation/pages/login_page.dart';
import 'package:entrenaop/features/auth/presentation/pages/sign_up_page.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/initial_assessment_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/physical_assessment_history_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_assessment_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_calculator_page.dart';
import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/profile/presentation/pages/profile_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_detail_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_detail_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_goal_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/running_test_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/running_week_simulator_page.dart';
import 'package:entrenaop/features/preparation_goal/data/repositories/running_test_repository.dart';
import 'package:entrenaop/features/training_plan/domain/repositories/training_preferences_repository.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_plan_page.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_hub_page.dart';
import 'package:entrenaop/features/training_plan/presentation/bloc/training_preferences_cubit.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_cubit.dart';
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

  AppRouter(AuthCubit authCubit) : _notifier = RouterNotifier(authCubit) {
    // Hace que `push` actualice también la URL web. Sin esta opción la pantalla
    // cambiaba, pero el navegador seguía mostrando /home.
    GoRouter.optionURLReflectsImperativeAPIs = true;
    config = GoRouter(
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
                  builder: (context, state) => BlocProvider(
                    create: (_) => sl<DashboardCubit>(),
                    child: const HomePage(),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/plan',
                  builder: (context, state) => const TrainingHubPage(),
                  routes: [
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
                        child: const WorkoutSchedulePage(),
                      ),
                      routes: [
                        GoRoute(
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
                      builder: (context, state) => BlocProvider(
                        create: (_) => sl<TrainingPreferencesCubit>(),
                        child: const TrainingPlanPage(),
                      ),
                    ),
                    GoRoute(
                      path: 'goal',
                      builder: (context, state) => BlocProvider(
                        create: (_) => sl<PreparationGoalCubit>(),
                        child: const PreparationGoalPage(),
                      ),
                      routes: [
                        GoRoute(
                          path: ':goalId',
                          builder: (context, state) => BlocProvider(
                            create: (_) => sl<PreparationDetailCubit>(
                              param1: state.pathParameters['goalId']!,
                            ),
                            child: const PreparationDetailPage(),
                          ),
                          routes: [
                            GoRoute(
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
                              builder: (context, state) =>
                                  RunningWeekSimulatorPage(
                                    goalId: state.pathParameters['goalId']!,
                                    loadRunningTests:
                                        sl<RunningTestRepository>().history,
                                    loadPreferences:
                                        sl<TrainingPreferencesRepository>().get,
                                  ),
                            ),
                            GoRoute(
                              path: 'running-test',
                              builder: (context, state) => RunningTestPage(
                                goalId: state.pathParameters['goalId']!,
                                repository: sl(),
                              ),
                              routes: [
                                GoRoute(
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
                    GoRoute(
                      path: 'starter-session',
                      builder: (context, state) => BlocProvider(
                        create: (_) => sl<WorkoutPreviewCubit>(
                          param1: GetStarterWorkoutUseCase.starterTemplateId,
                        ),
                        child: const WorkoutPreviewPage(
                          routeBase: '/plan/starter-session',
                        ),
                      ),
                      routes: [
                        GoRoute(
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
                      path: 'library',
                      builder: (context, state) => BlocProvider(
                        create: (_) => sl<WorkoutLibraryCubit>(),
                        child: const WorkoutLibraryPage(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'new',
                          builder: (context, state) => BlocProvider(
                            create: (_) => sl<WorkoutEditorCubit>(param1: ''),
                            child: const WorkoutEditorPage(),
                          ),
                        ),
                        GoRoute(
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
                            final templateId =
                                state.pathParameters['templateId']!;
                            return BlocProvider(
                              create: (_) =>
                                  sl<WorkoutPreviewCubit>(param1: templateId),
                              child: WorkoutPreviewPage(
                                routeBase: '/plan/library/$templateId',
                              ),
                            );
                          },
                          routes: [
                            GoRoute(
                              path: 'edit',
                              builder: (context, state) => BlocProvider(
                                create: (_) => sl<WorkoutEditorCubit>(
                                  param1: state.pathParameters['templateId']!,
                                ),
                                child: const WorkoutEditorPage(),
                              ),
                            ),
                            GoRoute(
                              path: 'edit-running',
                              builder: (context, state) => BlocProvider(
                                create: (_) => sl<WorkoutEditorCubit>(
                                  param1:
                                      'running:${state.pathParameters['templateId']!}',
                                ),
                                child: const RunningWorkoutEditorPage(),
                              ),
                            ),
                            GoRoute(
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
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/assessment/history',
                  builder: (context, state) => BlocProvider(
                    create: (_) => sl<WorkoutHistoryCubit>(),
                    child: const WorkoutHistoryPage(),
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
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/assessment/initial',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<PhysicalAssessmentCubit>(),
            child: const InitialAssessmentPage(),
          ),
        ),
        GoRoute(
          path: '/assessment/fas-calculator',
          builder: (context, state) => FasPeriodicCalculatorPage(
            birthDateRepository: sl(),
          ),
        ),
      ],
    );
  }

  void dispose() {
    config.dispose();
    _notifier.dispose();
  }
}

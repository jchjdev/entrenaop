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
import 'package:entrenaop/features/profile/presentation/pages/profile_page.dart';
import 'package:entrenaop/features/preparation_goal/presentation/bloc/preparation_goal_cubit.dart';
import 'package:entrenaop/features/preparation_goal/presentation/pages/preparation_goal_page.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_plan_page.dart';
import 'package:entrenaop/features/training_plan/presentation/bloc/training_preferences_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/workout_preview_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/bloc/active_workout_cubit.dart';
import 'package:entrenaop/features/workouts/presentation/pages/active_workout_page.dart';
import 'package:entrenaop/features/workouts/presentation/pages/workout_preview_page.dart';
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
                  builder: (context, state) => BlocProvider(
                    create: (_) => sl<TrainingPreferencesCubit>(),
                    child: const TrainingPlanPage(),
                  ),
                  routes: [
                    GoRoute(
                      path: 'goal',
                      builder: (context, state) => BlocProvider(
                        create: (_) => sl<PreparationGoalCubit>(),
                        child: const PreparationGoalPage(),
                      ),
                    ),
                    GoRoute(
                      path: 'starter-session',
                      builder: (context, state) => BlocProvider(
                        create: (_) => sl<WorkoutPreviewCubit>(),
                        child: const WorkoutPreviewPage(),
                      ),
                      routes: [
                        GoRoute(
                          path: 'active/:executionId',
                          builder: (context, state) => BlocProvider(
                            create: (_) => sl<ActiveWorkoutCubit>(
                              param1: state.pathParameters['executionId']!,
                            ),
                            child: ActiveWorkoutPage(timerStore: sl()),
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
                    create: (_) => sl<PhysicalAssessmentHistoryCubit>(),
                    child: const PhysicalAssessmentHistoryPage(),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfilePage(),
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
      ],
    );
  }

  void dispose() {
    config.dispose();
    _notifier.dispose();
  }
}

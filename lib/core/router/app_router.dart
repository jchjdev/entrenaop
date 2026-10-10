import 'dart:async';

import 'package:entrenaop/core/router/material_app_route.dart';

import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:entrenaop/features/auth/presentation/bloc/auth_state.dart';
import 'package:entrenaop/features/auth/presentation/pages/home_page.dart';
import 'package:entrenaop/features/dashboard/presentation/widgets/home_tools_section.dart';
import 'package:entrenaop/features/auth/presentation/pages/login_page.dart';
import 'package:entrenaop/features/auth/presentation/pages/sign_up_page.dart';
import 'package:entrenaop/features/auth/presentation/pages/account_email_page.dart';
import 'package:entrenaop/features/auth/presentation/pages/reset_password_page.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/exercises/domain/usecases/create_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercise_by_id_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/update_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/presentation/pages/personal_exercise_editor_page.dart';
import 'package:entrenaop/features/exercises/presentation/bloc/exercise_library_cubit.dart';
import 'package:entrenaop/features/exercises/presentation/pages/exercise_library_page.dart';
import 'package:entrenaop/features/library/presentation/library_hub_page.dart';
import 'package:entrenaop/features/exercises/presentation/pages/personal_exercise_creator_page.dart';
import 'package:entrenaop/core/di/injection_container.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/bloc/physical_assessment_history_cubit.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/initial_assessment_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/physical_assessment_history_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/preparation_marks_page.dart';
import 'package:entrenaop/features/physical_assessment/domain/repositories/physical_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_assessment_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_calculator_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/fas_periodic_history_page.dart';
import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/profile/presentation/pages/profile_page.dart';
import 'package:entrenaop/features/pro/domain/pro_offer.dart';
import 'package:entrenaop/features/pro/presentation/pages/pro_pages.dart';
import 'package:entrenaop/features/pro/domain/pro_access.dart';
import 'package:entrenaop/features/pro/presentation/widgets/pro_access_widgets.dart';
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
        if (authState is AuthPasswordRecovery) {
          return state.matchedLocation == '/reset-password'
              ? null
              : '/reset-password';
        }
        if (authState is AuthLinkError) {
          return state.matchedLocation == '/auth-link-error'
              ? null
              : '/auth-link-error';
        }
        if (authState is AuthEmailConfirmationRequired &&
            (state.matchedLocation == '/' ||
                state.matchedLocation == '/sign-up')) {
          return '/confirm-email';
        }
        final isAuthenticated = authState is AuthAuthenticated;
        final isLoading = authState is AuthLoading || authState is AuthInitial;
        final isPublicRoute = const [
          '/',
          '/sign-up',
          '/forgot-password',
          '/confirm-email',
          '/reset-password',
          '/auth-link-error',
        ].contains(state.matchedLocation);

        if (isLoading) return null;
        if (!isAuthenticated && !isPublicRoute) return '/';
        if (isAuthenticated && isPublicRoute) return '/home';
        return null;
      },
      routes: [
        materialAppRoute(
          path: '/pro',
          builder: (_, state) => ProOfferPage(
            offerContext: ProOfferContext.fromUri(state.uri),
            loadAccess: sl<ProAccessRepository>().load,
          ),
        ),
        materialAppRoute(
          path: '/pro/example',
          builder: (_, state) =>
              ProExamplePage(offerContext: ProOfferContext.fromUri(state.uri)),
        ),
        materialAppRoute(
          path: '/pro/subscription',
          builder: (_, _) =>
              ProSubscriptionPage(loadAccess: sl<ProAccessRepository>().load),
        ),
        materialAppRoute(
          path: '/forgot-password',
          builder: (_, state) => AccountEmailPage(
            initialEmail: state.extra is String ? state.extra as String : '',
          ),
        ),
        materialAppRoute(
          path: '/confirm-email',
          builder: (_, _) => const AccountEmailPage(confirmation: true),
        ),
        materialAppRoute(
          path: '/reset-password',
          builder: (_, _) => const ResetPasswordPage(),
        ),
        materialAppRoute(
          path: '/auth-link-error',
          builder: (_, _) => const AccountLinkErrorPage(),
        ),
        materialAppRoute(
          path: '/',
          builder: (context, state) => const LoginPage(),
        ),
        materialAppRoute(
          path: '/sign-up',
          builder: (context, state) => const SignUpPage(),
        ),
        StatefulShellRoute.indexedStack(
          pageBuilder: (context, state, navigationShell) =>
              MaterialPage<Object?>(
                key: state.pageKey,
                restorationId: state.pageKey.value,
                child: AppShell(navigationShell: navigationShell),
              ),
          branches: [
            StatefulShellBranch(
              routes: [
                materialAppRoute(
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
                materialAppRoute(
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
                            loadProAccess: sl<ProAccessRepository>().load,
                          );
                        },
                      ),
                  routes: [
                    materialAppRoute(
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
                    materialAppRoute(
                      path: 'preferences',
                      redirect: (context, state) => '/profile/preferences',
                    ),
                    materialAppRoute(
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
                        materialAppRoute(
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
                              loadProAccess: sl<ProAccessRepository>().load,
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
                              builder: (context, state) => ProAccessGate(
                                load: sl<ProAccessRepository>().load,
                                offerContext: ProOfferContext(
                                  goalId: state.pathParameters['goalId'],
                                ),
                                child: PreparationTrainingPage(
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
                              builder: (context, state) => BlocProvider(
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
                                      sl<RunningIntakeContextRepository>().get,
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
                                      sl<WorkoutScheduleRepository>().getRange,
                                  calculateWeek:
                                      sl<RunningWeekPlanRepository>().calculate,
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
                            materialAppRoute(
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
                            materialAppRoute(
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
                materialAppRoute(
                  path: '/library',
                  builder: (context, state) => const LibraryHubPage(),
                  routes: [
                    materialAppRoute(
                      path: 'exercises',
                      builder: (context, state) =>
                          BlocBuilder<AuthCubit, AuthState>(
                            buildWhen: (_, next) =>
                                next is AuthAuthenticated ||
                                next is AuthUnauthenticated,
                            builder: (context, auth) {
                              if (auth is! AuthAuthenticated) {
                                return const SizedBox.shrink();
                              }
                              final personal =
                                  state.uri.queryParameters['tab'] ==
                                  'personal';
                              return BlocProvider(
                                key: ValueKey(
                                  'exercises-${auth.user.id}-$personal',
                                ),
                                create: (_) => ExerciseLibraryCubit(
                                  getExercises: sl<GetExercisesUseCase>(),
                                  userId: auth.user.id,
                                )..load(),
                                child: ExerciseLibraryPage(
                                  loadProAccess: sl<ProAccessRepository>().load,
                                  initialPersonalTab: personal,
                                ),
                              );
                            },
                          ),
                      routes: [
                        _workflowRoute(
                          path: ':exerciseId/edit',
                          builder: (context, state) =>
                              BlocBuilder<AuthCubit, AuthState>(
                                buildWhen: (_, next) =>
                                    next is AuthAuthenticated ||
                                    next is AuthUnauthenticated,
                                builder: (context, auth) =>
                                    auth is AuthAuthenticated
                                    ? PersonalExerciseEditorPage(
                                        key: ValueKey(
                                          '${auth.user.id}-${state.pathParameters['exerciseId']}',
                                        ),
                                        exerciseId:
                                            state.pathParameters['exerciseId']!,
                                        userId: auth.user.id,
                                        getExercise:
                                            sl<GetExerciseByIdUseCase>(),
                                        updateExercise:
                                            sl<UpdateExerciseUseCase>(),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                        ),
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
                materialAppRoute(
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
                materialAppRoute(
                  path: '/plan/library',
                  builder: (context, state) => BlocProvider(
                    create: (_) => sl<WorkoutLibraryCubit>(),
                    child: WorkoutLibraryPage(
                      loadProAccess: sl<ProAccessRepository>().load,
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
                    materialAppRoute(
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
                materialAppRoute(
                  path: '/assessment/history',
                  builder: (context, state) =>
                      BlocBuilder<AuthCubit, AuthState>(
                        bloc: authCubit,
                        buildWhen: (_, next) =>
                            next is AuthAuthenticated ||
                            next is AuthUnauthenticated,
                        builder: (context, auth) => auth is! AuthAuthenticated
                            ? const SizedBox.shrink()
                            : BlocProvider(
                                key: ValueKey('history-${auth.user.id}'),
                                create: (_) => sl<WorkoutHistoryCubit>(),
                                child: WorkoutHistoryPage(
                                  loadPreparations:
                                      sl<PreparationGoalRepository>()
                                          .getActiveGoals,
                                ),
                              ),
                      ),
                  routes: [
                    materialAppRoute(
                      path: 'preparations/:goalId',
                      builder: (context, state) => BlocBuilder<AuthCubit, AuthState>(
                        bloc: authCubit,
                        buildWhen: (_, next) =>
                            next is AuthAuthenticated ||
                            next is AuthUnauthenticated,
                        builder: (context, auth) => auth is! AuthAuthenticated
                            ? const SizedBox.shrink()
                            : PreparationMarksPage(
                                key: ValueKey(
                                  'marks-${auth.user.id}-${state.pathParameters['goalId']}',
                                ),
                                goalId: state.pathParameters['goalId']!,
                                load: (goalId) async {
                                  final goals =
                                      await sl<PreparationGoalRepository>()
                                          .getActiveGoals();
                                  final goal = goals
                                      .where((g) => g.id == goalId)
                                      .firstOrNull;
                                  if (goal == null) {
                                    throw StateError(
                                      'Preparación no disponible.',
                                    );
                                  }
                                  if (goal.programId ==
                                      PreparationProgramIds
                                          .fasPeriodicAssessment) {
                                    final history =
                                        await sl<
                                              FasPeriodicAssessmentRepository
                                            >()
                                            .history(goalId: goalId);
                                    return PreparationMarksData(
                                      goal: goal,
                                      fas: history,
                                      fasReference:
                                          await FasPeriodic2027Reference.load(),
                                    );
                                  }
                                  final program =
                                      await sl<ProgramAssessmentRepository>()
                                          .history(goalId);
                                  if (goal.programId !=
                                      PreparationProgramIds
                                          .armedForcesTroopEntry) {
                                    return PreparationMarksData(
                                      goal: goal,
                                      program: program,
                                    );
                                  }
                                  return PreparationMarksData(
                                    goal: goal,
                                    program: program,
                                    troop:
                                        await sl<PhysicalAssessmentRepository>()
                                            .getHistoryForGoal(goalId),
                                    running: await sl<RunningTestRepository>()
                                        .history(goalId),
                                  );
                                },
                              ),
                      ),
                    ),
                    materialAppRoute(
                      path: 'physical',
                      builder: (context, state) =>
                          BlocBuilder<AuthCubit, AuthState>(
                            bloc: authCubit,
                            buildWhen: (_, next) =>
                                next is AuthAuthenticated ||
                                next is AuthUnauthenticated,
                            builder: (_, auth) => auth is! AuthAuthenticated
                                ? const SizedBox.shrink()
                                : BlocProvider(
                                    key: ValueKey(
                                      'physical-history-${auth.user.id}',
                                    ),
                                    create: (_) =>
                                        sl<PhysicalAssessmentHistoryCubit>(),
                                    child:
                                        const PhysicalAssessmentHistoryPage(),
                                  ),
                          ),
                    ),
                    materialAppRoute(
                      path: 'workouts/:executionId',
                      builder: (context, state) =>
                          BlocBuilder<AuthCubit, AuthState>(
                            bloc: authCubit,
                            buildWhen: (_, next) =>
                                next is AuthAuthenticated ||
                                next is AuthUnauthenticated,
                            builder: (_, auth) => auth is! AuthAuthenticated
                                ? const SizedBox.shrink()
                                : BlocProvider(
                                    key: ValueKey(
                                      'history-detail-${auth.user.id}-${state.pathParameters['executionId']}',
                                    ),
                                    create: (_) =>
                                        sl<WorkoutHistoryDetailCubit>(
                                          param1: state
                                              .pathParameters['executionId']!,
                                        ),
                                    child: const WorkoutHistoryDetailPage(),
                                  ),
                          ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                materialAppRoute(
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
        materialAppRoute(
          path: '/assessment/fas-calculator',
          builder: (context, state) => FasPeriodicCalculatorPage(
            birthDateRepository: sl(),
            repository: sl(),
          ),
        ),
        materialAppRoute(
          path: '/tools/running-pace-calculator',
          builder: (context, state) => const RunningPaceCalculatorPage(),
        ),
        materialAppRoute(
          path: '/tools',
          builder: (context, state) => const HomeToolsPage(),
        ),
        _workflowRoute(
          path: '/exercises/new',
          builder: (context, state) => PersonalExerciseCreatorPage(
            createExercise: sl<CreateExerciseUseCase>(),
          ),
        ),
        materialAppRoute(
          path: '/assessment/fas-history',
          builder: (context, state) => BlocBuilder<AuthCubit, AuthState>(
            bloc: authCubit,
            buildWhen: (_, next) =>
                next is AuthAuthenticated || next is AuthUnauthenticated,
            builder: (_, auth) => auth is! AuthAuthenticated
                ? const SizedBox.shrink()
                : FasPeriodicHistoryPage(
                    key: ValueKey('fas-history-${auth.user.id}'),
                    repository: sl(),
                  ),
          ),
        ),
      ],
    );
  }

  GoRoute _workflowRoute({
    required String path,
    required GoRouterWidgetBuilder builder,
    GoRouterRedirect? redirect,
    List<RouteBase> routes = const [],
  }) => materialAppRoute(
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

import 'dart:async';

import 'package:entrenaop/features/notifications/push_notifications_scope.dart';

import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_calendar.dart';
import 'package:trainer_access/trainer_messages.dart';
import 'package:entrenaop/features/trainers/presentation/trainer_conversation_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:entrenaop/features/trainers/presentation/my_trainer_page.dart';
import 'package:entrenaop/features/trainers/data/trainer_student_form_repository.dart';
import 'package:entrenaop/features/trainers/presentation/pages/trainer_forms_page.dart';
import 'package:entrenaop/features/trainers/presentation/pages/trainer_assessments_page.dart';
import 'package:entrenaop/features/trainers/data/trainer_assessment_repository.dart';
import 'package:entrenaop/features/trainers/data/supabase_student_notice_repository.dart';
import 'package:entrenaop/features/trainers/presentation/pages/professional_hub_page.dart';
import 'package:entrenaop/features/trainers/presentation/pages/professional_technique_page.dart';
import 'package:entrenaop/features/workouts/data/services/client_technique_repository.dart';

import 'package:entrenaop/core/router/material_app_route.dart';
import 'package:entrenaop/core/router/device_activities_route.dart';
import 'package:entrenaop/core/router/garmin_connection_route.dart';

import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/features/trainers/presentation/student_navigation.dart';
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
import 'package:entrenaop/features/guided_programs/domain/guided_program_repository.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_program_cubits.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_program_page.dart';
import 'package:entrenaop/features/guided_programs/presentation/guided_session_page.dart';
import 'package:entrenaop/features/workouts/domain/usecases/workout_execution_usecases.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
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
import 'package:entrenaop/features/pro/domain/pro_purchases.dart';
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
  ProPurchaseRepository? get _purchases =>
      sl.isRegistered<ProPurchaseRepository>()
      ? sl<ProPurchaseRepository>()
      : null;
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
          builder: (_, state) => BlocBuilder<AuthCubit, AuthState>(
            bloc: authCubit,
            builder: (_, auth) => auth is! AuthAuthenticated
                ? const SizedBox.shrink()
                : ProOfferPage(
                    key: ValueKey(auth.user.id),
                    offerContext: ProOfferContext.fromUri(state.uri),
                    loadAccess: sl<ProAccessRepository>().load,
                    purchases: _purchases,
                  ),
          ),
        ),
        materialAppRoute(
          path: '/pro/example',
          builder: (_, state) =>
              ProExamplePage(offerContext: ProOfferContext.fromUri(state.uri)),
        ),
        materialAppRoute(
          path: '/pro/subscription',
          builder: (_, _) => BlocBuilder<AuthCubit, AuthState>(
            bloc: authCubit,
            builder: (_, auth) => auth is! AuthAuthenticated
                ? const SizedBox.shrink()
                : ProSubscriptionPage(
                    key: ValueKey(auth.user.id),
                    loadAccess: sl<ProAccessRepository>().load,
                    purchases: _purchases,
                  ),
          ),
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
        materialAppRoute(
          path: '/plan/starter-session',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<WorkoutPreviewCubit>(
              param1: GetStarterWorkoutUseCase.starterTemplateId,
            ),
            child: const WorkoutPreviewPage(routeBase: '/plan/starter-session'),
          ),
          routes: [
            _workflowRoute(
              path: 'active/:executionId',
              builder: (context, state) => BlocProvider(
                create: (_) => sl<ActiveWorkoutCubit>(
                  param1: state.pathParameters['executionId']!,
                ),
                child: ActiveWorkoutPage(timerStore: sl(), cueService: sl()),
              ),
            ),
          ],
        ),
        StatefulShellRoute.indexedStack(
          pageBuilder: (context, state, navigationShell) =>
              MaterialPage<Object?>(
                key: state.pageKey,
                restorationId: state.pageKey.value,
                child: BlocBuilder<AuthCubit, AuthState>(
                  bloc: authCubit,
                  // Renovar el token no debe desmontar las pilas de navegación.
                  buildWhen: (_, next) =>
                      next is AuthAuthenticated || next is AuthUnauthenticated,
                  builder: (context, auth) => auth is! AuthAuthenticated
                      ? const SizedBox.shrink()
                      : StudentNavigationEntry(
                          noticeEvents: PushNotificationsScope.readOf(context)
                              ?.notices,
                          key: ValueKey('navigation-${auth.user.id}'),
                          loadSnapshot: () => SupabaseStudentNoticeRepository(
                            sl<SupabaseClient>(),
                            auth.user.id,
                          ).snapshot(),
                          loadHasRelationship: () async {
                            final repository = SupabaseTrainerRepository(
                              sl<SupabaseClient>(),
                              userId: auth.user.id,
                            );
                            final active = await repository.relations(
                              asTrainer: false,
                            );
                            if (active.isNotEmpty) return true;
                            final history = await repository.relations(
                              asTrainer: false,
                              ended: true,
                            );
                            return history.isNotEmpty;
                          },
                          child: AppShell(navigationShell: navigationShell),
                        ),
                ),
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
                        guidedPrograms:
                            sl.isRegistered<GuidedProgramRepository>()
                            ? sl<GuidedProgramRepository>()
                            : null,
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
                              builder: (context, state) => BlocBuilder<AuthCubit, AuthState>(
                                bloc: authCubit,
                                builder: (_, auth) => auth is! AuthAuthenticated
                                    ? const SizedBox.shrink()
                                    : ProAccessGate(
                                        key: ValueKey(auth.user.id),
                                        purchases: _purchases,
                                        load: sl<ProAccessRepository>().load,
                                        offerContext: ProOfferContext(
                                          goalId:
                                              state.pathParameters['goalId'],
                                        ),
                                        child: PreparationTrainingPage(
                                          key: ValueKey(
                                            'training-${state.pathParameters['goalId']}',
                                          ),
                                          goalId:
                                              state.pathParameters['goalId']!,
                                          runningStepBuilder: (context, next, back) => BlocProvider(
                                            key: ValueKey(
                                              'training-running-${state.pathParameters['goalId']}',
                                            ),
                                            create: (_) =>
                                                sl<PreparationDetailCubit>(
                                                  param1: state
                                                      .pathParameters['goalId']!,
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
                                              sl<
                                                PreparationTrainingRepository
                                              >(),
                                          initialWeek: DateTime.tryParse(
                                            state.uri.queryParameters['week'] ??
                                                '',
                                          ),
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
                  builder: (context, state) =>
                      BlocBuilder<AuthCubit, AuthState>(
                        bloc: authCubit,
                        builder: (_, auth) => LibraryHubPage(
                          initialTab:
                              state.uri.queryParameters['tab'] ?? 'sessions',
                          key: ValueKey(
                            auth is AuthAuthenticated
                                ? auth.user.id
                                : 'library',
                          ),
                          guided: sl.isRegistered<GuidedProgramRepository>()
                              ? sl<GuidedProgramRepository>()
                              : null,
                        ),
                      ),
                  routes: [
                    materialAppRoute(
                      path: 'programs/:guidedId',
                      builder: (_, state) => BlocProvider(
                        key: ValueKey(state.pathParameters['guidedId']),
                        create: (_) => GuidedDetailCubit(
                          sl<GuidedProgramRepository>(),
                          state.pathParameters['guidedId']!,
                        )..load(),
                        child: const GuidedProgramPage(),
                      ),
                      routes: [
                        materialAppRoute(
                          path: 'session/:phaseIndex/:sessionIndex',
                          parentNavigatorKey: _rootNavigatorKey,
                          builder: (_, state) => GuidedSessionPage(
                            key: ValueKey(state.uri.path),
                            repository: sl<GuidedProgramRepository>(),
                            workouts: sl<WorkoutRepository>(),
                            programId: state.pathParameters['guidedId']!,
                            phaseIndex:
                                int.tryParse(
                                  state.pathParameters['phaseIndex']!,
                                ) ??
                                -1,
                            sessionIndex:
                                int.tryParse(
                                  state.pathParameters['sessionIndex']!,
                                ) ??
                                -1,
                            getTemplate: sl<GetWorkoutTemplateUseCase>(),
                            startDefault: sl<StartWorkoutExecutionUseCase>(),
                            getExercise: sl<GetExerciseByIdUseCase>(),
                          ),
                          routes: [
                            _workflowRoute(
                              path: 'active/:executionId',
                              builder: (_, state) => BlocProvider(
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
                      parentNavigatorKey: _rootNavigatorKey,
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
                  path: '/my-trainer',
                  builder: (_, state) => BlocBuilder<AuthCubit, AuthState>(
                    bloc: authCubit,
                    builder: (context, auth) => auth is! AuthAuthenticated
                        ? const SizedBox.shrink()
                        : ProfessionalHubPage(
                            noticeEvents: PushNotificationsScope.readOf(context)
                                ?.notices,
                            key: ValueKey('professional-hub-${auth.user.id}'),
                            userId: auth.user.id,
                            focusNotices:
                                state.uri.queryParameters['view'] == 'notices',
                            repository: SupabaseStudentNoticeRepository(
                              sl<SupabaseClient>(),
                              auth.user.id,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
        materialAppRoute(
          path: '/profile',
          builder: (context, state) => ProfilePage(
            preparations: sl(),
            birthDateRepository: sl(),
            nameRepository: sl(),
          ),
          routes: [
            materialAppRoute(
              path: 'trainer',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, _) => BlocBuilder<AuthCubit, AuthState>(
                bloc: authCubit,
                builder: (context, auth) => auth is! AuthAuthenticated
                    ? const SizedBox.shrink()
                    : MyTrainerPage(
                        calendarSharing:
                            SupabaseTrainerCalendarSharingRepository(
                              sl<SupabaseClient>(),
                              auth.user.id,
                            ),
                        key: ValueKey(auth.user.id),
                        repository: SupabaseTrainerRepository(
                          sl<SupabaseClient>(),
                          userId: auth.user.id,
                        ),
                        forms: SupabaseTrainerStudentFormRepository(
                          sl<SupabaseClient>(),
                          auth.user.id,
                        ),
                        assessments:
                            SupabaseProfessionalAssessmentStudentRepository(
                              sl<SupabaseClient>(),
                              auth.user.id,
                            ),
                        onOpenConversation: (id) =>
                            context.push('/my-trainer/conversations/$id'),
                      ),
              ),
            ),
            materialAppRoute(
              path: 'garmin',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, _) => BlocBuilder<AuthCubit, AuthState>(
                bloc: authCubit,
                builder: (_, auth) => auth is! AuthAuthenticated
                    ? const SizedBox.shrink()
                    : GarminConnectionRoute(
                        key: ValueKey('garmin-${auth.user.id}'),
                        ownerId: auth.user.id,
                        client: sl<SupabaseClient>(),
                      ),
              ),
            ),
            materialAppRoute(
              path: 'garmin-training',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, _) => BlocBuilder<AuthCubit, AuthState>(
                bloc: authCubit,
                builder: (_, auth) => auth is! AuthAuthenticated
                    ? const SizedBox.shrink()
                    : GarminTrainingRoute(
                        key: ValueKey('garmin-training-${auth.user.id}'),
                        ownerId: auth.user.id,
                        client: sl<SupabaseClient>(),
                      ),
              ),
            ),
            materialAppRoute(
              path: 'garmin-ciq',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, _) => BlocBuilder<AuthCubit, AuthState>(
                bloc: authCubit,
                builder: (_, auth) => auth is! AuthAuthenticated
                    ? const SizedBox.shrink()
                    : GarminCiqRoute(
                        key: ValueKey('garmin-ciq-${auth.user.id}'),
                        ownerId: auth.user.id,
                        client: sl<SupabaseClient>(),
                      ),
              ),
            ),
            materialAppRoute(
              path: 'garmin-activities',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, _) => BlocBuilder<AuthCubit, AuthState>(
                bloc: authCubit,
                builder: (_, auth) => auth is! AuthAuthenticated
                    ? const SizedBox.shrink()
                    : GarminActivitiesRoute(
                        key: ValueKey('garmin-activities-${auth.user.id}'),
                        ownerId: auth.user.id,
                        client: sl<SupabaseClient>(),
                      ),
              ),
            ),
            materialAppRoute(
              path: 'activities',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (_, _) => BlocBuilder<AuthCubit, AuthState>(
                bloc: authCubit,
                builder: (_, auth) => auth is! AuthAuthenticated
                    ? const SizedBox.shrink()
                    : DeviceActivitiesRoute(
                        key: ValueKey('activities-${auth.user.id}'),
                        ownerId: auth.user.id,
                        client: sl<SupabaseClient>(),
                      ),
              ),
            ),
            _workflowRoute(
              path: 'preferences',
              builder: (context, state) => TrainingContextPage(
                repository: sl<TrainingContextRepository>(),
              ),
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
          path: '/my-trainer/technique',
          builder: (_, state) => BlocBuilder<AuthCubit, AuthState>(
            bloc: authCubit,
            builder: (_, auth) => auth is! AuthAuthenticated
                ? const SizedBox.shrink()
                : ProfessionalTechniqueIndexPage(
                    key: ValueKey('professional-technique-${auth.user.id}'),
                    userId: auth.user.id,
                    repository: SupabaseStudentNoticeRepository(
                      sl<SupabaseClient>(),
                      auth.user.id,
                    ),
                  ),
          ),
        ),
        _workflowRoute(
          path: '/my-trainer/technique/:executionId',
          builder: (_, state) => BlocBuilder<AuthCubit, AuthState>(
            bloc: authCubit,
            builder: (_, auth) => auth is! AuthAuthenticated
                ? const SizedBox.shrink()
                : ProfessionalTechniquePage(
                    key: ValueKey(
                      'professional-technique-${auth.user.id}-${state.pathParameters['executionId']}',
                    ),
                    userId: auth.user.id,
                    executionId: state.pathParameters['executionId']!,
                    workouts: sl<WorkoutRepository>(),
                    technique: SupabaseClientTechniqueRepository(
                      sl<SupabaseClient>(),
                      auth.user.id,
                    ),
                  ),
          ),
        ),
        materialAppRoute(
          path: '/my-trainer/assessments',
          builder: (_, state) => BlocBuilder<AuthCubit, AuthState>(
            bloc: authCubit,
            builder: (_, auth) => auth is! AuthAuthenticated
                ? const SizedBox.shrink()
                : TrainerStudentAssessmentsPage(
                    key: ValueKey('assessments-${auth.user.id}'),
                    repository: SupabaseProfessionalAssessmentStudentRepository(
                      sl<SupabaseClient>(),
                      auth.user.id,
                    ),
                  ),
          ),
        ),
        _workflowRoute(
          path: '/my-trainer/assessments/:id',
          builder: (_, state) => BlocBuilder<AuthCubit, AuthState>(
            bloc: authCubit,
            builder: (_, auth) => auth is! AuthAuthenticated
                ? const SizedBox.shrink()
                : TrainerStudentAssessmentPage(
                    key: ValueKey(
                      'assessment-${auth.user.id}-${state.pathParameters['id']}',
                    ),
                    repository: SupabaseProfessionalAssessmentStudentRepository(
                      sl<SupabaseClient>(),
                      auth.user.id,
                    ),
                    deliveryId: state.pathParameters['id']!,
                  ),
          ),
        ),
        materialAppRoute(
          path: '/my-trainer/forms',
          builder: (context, state) => BlocBuilder<AuthCubit, AuthState>(
            bloc: authCubit,
            builder: (_, auth) => auth is! AuthAuthenticated
                ? const SizedBox.shrink()
                : TrainerStudentFormsPage(
                    key: ValueKey('trainer-forms-${auth.user.id}'),
                    repository: SupabaseTrainerStudentFormRepository(
                      sl<SupabaseClient>(),
                      auth.user.id,
                    ),
                  ),
          ),
        ),
        _workflowRoute(
          path: '/my-trainer/conversations/:id',
          builder: (context, state) => BlocBuilder<AuthCubit, AuthState>(
            bloc: authCubit,
            builder: (_, auth) => auth is! AuthAuthenticated
                ? const SizedBox.shrink()
                : TrainerStudentConversationPage(
                    key: ValueKey(
                      'conversation-${auth.user.id}-${state.pathParameters['id']}',
                    ),
                    relationId: state.pathParameters['id']!,
                    repository: SupabaseTrainerMessageRepository(
                      sl<SupabaseClient>(),
                      auth.user.id,
                    ),
                  ),
          ),
        ),
        _workflowRoute(
          path: '/my-trainer/forms/:id',
          builder: (context, state) => BlocBuilder<AuthCubit, AuthState>(
            bloc: authCubit,
            builder: (_, auth) => auth is! AuthAuthenticated
                ? const SizedBox.shrink()
                : TrainerStudentFormPage(
                    key: ValueKey(
                      'trainer-form-${auth.user.id}-${state.pathParameters['id']}',
                    ),
                    assignmentId: state.pathParameters['id']!,
                    repository: SupabaseTrainerStudentFormRepository(
                      sl<SupabaseClient>(),
                      auth.user.id,
                    ),
                  ),
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

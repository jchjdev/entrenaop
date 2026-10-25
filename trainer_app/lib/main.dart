import 'trainer_client_goals_repository.dart';
import 'trainer_client_goals.dart';
import 'trainer_client_planning_repository.dart';
import 'trainer_client_planning_page.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/guided_program_work.dart';
import 'package:entrena_ui/conversation_view.dart';
import 'package:trainer_access/trainer_messages.dart';

import 'trainer_clients_page.dart';
import 'trainer_security_page.dart';
import 'trainer_workout_pages.dart';
import 'trainer_workout_result.dart';
import 'trainer_workout_repository.dart';
import 'trainer_workout_work_repository.dart';
import 'trainer_session_work_editor.dart';
import 'trainer_program_repository.dart';
import 'trainer_program_pages.dart';
import 'trainer_program_work_repository.dart';
import 'trainer_program_work_pages.dart';
import 'trainer_agenda_page.dart';
import 'trainer_shared_calendar_page.dart';
import 'trainer_assignment_work_page.dart';
import 'trainer_assignment_work_repository.dart';

import 'package:trainer_access/trainer_calendar.dart';

import 'trainer_shell.dart';
import 'trainer_account_page.dart';
import 'trainer_exercise_page.dart';
import 'trainer_exercise_repository.dart';
import 'trainer_video_repository.dart';
import 'trainer_operations_repository.dart';
import 'trainer_operations_pages.dart';
import 'trainer_home_page.dart';
import 'trainer_form_repository.dart';
import 'trainer_form_pages.dart';
import 'trainer_groups_repository.dart';
import 'trainer_groups_page.dart';
import 'trainer_week_copy_dialog.dart';
import 'trainer_client_workspace.dart';
import 'trainer_client_navigation.dart';
import 'trainer_client_directories.dart';
import 'trainer_client_workspace_repository.dart';
import 'trainer_client_forms_route.dart';
import 'trainer_media_repository.dart';
import 'trainer_media_page.dart';
import 'trainer_technique_page.dart';
import 'trainer_recurrence_repository.dart';
import 'trainer_recurrence_page.dart';
import 'trainer_assessment_pages.dart';
import 'trainer_assessment_repository.dart';
import 'trainer_exercise_preferences_repository.dart';

import 'package:trainer_access/trainer_security.dart';

abstract final class TrainerConfig {
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://sxbxfjqgoddzhtcyhalw.supabase.co',
  );
  static const key = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_n6qWrY5f6dG_3fJpXwctZQ_Nlvu_x7Z',
  );
  static void validate() {
    if (!['development', 'production'].contains(environment) ||
        url.isEmpty ||
        key.isEmpty ||
        !url.startsWith('https://') ||
        (environment == 'production' && url.contains('sxbxfjqgoddzhtcyhalw'))) {
      throw StateError('Configuración del panel profesional no válida.');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  TrainerConfig.validate();
  await Supabase.initialize(
    url: TrainerConfig.url,
    publishableKey: TrainerConfig.key,
  );
  runApp(TrainerApp(client: Supabase.instance.client));
}

class TrainerApp extends StatefulWidget {
  const TrainerApp({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<TrainerApp> createState() => _TrainerAppState();
}

class _TrainerAppState extends State<TrainerApp> {
  late GoRouter _router;
  late final StreamSubscription<AuthState> _subscription;
  String? _identity;
  String? get _currentIdentity {
    final user = widget.client.auth.currentUser;
    return user == null || user.isAnonymous ? null : user.id;
  }

  @override
  void initState() {
    super.initState();
    _identity = _currentIdentity;
    _router = _createRouter();
    _subscription = widget.client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      if (_identity == _currentIdentity) {
        _router.refresh();
        return;
      }
      final previous = _router;
      setState(() {
        _identity = _currentIdentity;
        _router = _createRouter();
      });
      // La identidad forma parte de la raíz: ni códigos ni listas sobreviven
      // a un cierre de sesión o al cambio de cuenta.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    });
  }

  GoRouter _createRouter() {
    final identity = _identity;
    final exits = WorkflowExitRegistry();
    GoRouter.optionURLReflectsImperativeAPIs = true;
    // Estas instancias pertenecen a la identidad del router. Una renovación
    // de sesión no debe reiniciar el trabajo abierto ni sus campos pendientes.
    late final workoutRepository = SupabaseTrainerWorkoutRepository(
      widget.client,
      identity!,
    );
    late final programRepository = SupabaseTrainerProgramRepository(
      widget.client,
      identity!,
    );
    late final programWorkRepository = SupabaseTrainerProgramWorkRepository(
      widget.client,
      identity!,
    );
    late final sessionWorkRepository = SupabaseTrainerWorkoutWorkRepository(
      widget.client,
      identity!,
    );
    SupabaseTrainerWorkoutRepository workouts() => workoutRepository;
    SupabaseTrainerProgramRepository programs() => programRepository;
    SupabaseTrainerProgramWorkRepository programWorks() =>
        programWorkRepository;
    SupabaseTrainerWorkoutWorkRepository sessionWorks() =>
        sessionWorkRepository;
    SupabaseTrainerRepository access() =>
        SupabaseTrainerRepository(widget.client, userId: identity!);
    SupabaseTrainerOperationsRepository operations() =>
        SupabaseTrainerOperationsRepository(widget.client, identity!);
    SupabaseTrainerAgendaRepository agenda() =>
        SupabaseTrainerAgendaRepository(widget.client, identity!);
    SupabaseTrainerAssessmentRepository assessments() =>
        SupabaseTrainerAssessmentRepository(widget.client, identity!);
    SupabaseTrainerFormRepository forms() =>
        SupabaseTrainerFormRepository(widget.client, identity!);
    SupabaseTrainerGroupsRepository groups() =>
        SupabaseTrainerGroupsRepository(widget.client, identity!);
    SupabaseTrainerClientWorkspaceRepository workspace() =>
        SupabaseTrainerClientWorkspaceRepository(widget.client, identity!);
    SupabaseTrainerMediaRepository media() =>
        SupabaseTrainerMediaRepository(widget.client, identity!);
    final exercisePreferences = identity == null
        ? null
        : SupabaseTrainerExercisePreferences(widget.client, identity);
    final videos = identity == null
        ? null
        : SupabaseTrainerVideoRepository(widget.client, identity);
    Future<WorkoutEditorExercise?> createExercise(BuildContext context) =>
        showTrainerExerciseEditor(
          context,
          SupabaseTrainerExerciseRepository(widget.client, identity!),
          videoSource: videos,
          mediaRepository: media(),
        );
    Widget guarded(GoRouterState state, Widget child) => WorkflowExitScope(
      controller: exits.controller(state.pageKey),
      child: child,
    );
    Widget conversation(String relationId, {String? assignmentId}) {
      final messages = SupabaseTrainerMessageRepository(
        widget.client,
        identity!,
      );
      return ConversationView(
        key: ValueKey('conversation-$identity-$relationId-$assignmentId'),
        header: () async {
          final detail = await messages.context(relationId);
          return ConversationHeader(
            title: detail.name,
            canSend: detail.canSend,
          );
        },
        load: (before) async =>
            (await messages.list(
                  relationId,
                  beforeAt: before?.createdAt,
                  beforeId: before?.id,
                ))
                .map(
                  (m) => ConversationEntry(
                    id: m.id,
                    body: m.body,
                    createdAt: m.createdAt,
                    mine: m.mine,
                    contextLabel: m.assignmentId == null
                        ? null
                        : 'Sobre una pauta del servicio',
                  ),
                )
                .toList(),
        send: (id, body) => messages.send(
          operationId: id,
          relationId: relationId,
          body: body,
          assignmentId: assignmentId,
        ),
        newOperationId: trainerMessageOperationId,
        errorLabel: trainerError,
      );
    }

    return GoRouter(
      initialLocation: identity == null ? '/login' : '/home',
      redirect: (_, state) async {
        if (_identity == null && state.matchedLocation != '/login') {
          return '/login';
        }
        if (_identity != null) {
          bool assured;
          try {
            assured = await SupabaseTrainerSecurity(
              widget.client,
              _identity!,
            ).assured();
          } catch (_) {
            assured = false;
          }
          if (_identity == null) return '/login';
          if (!assured && state.matchedLocation != '/security') {
            return '/security';
          }
          if (assured &&
              (state.matchedLocation == '/login' ||
                  state.matchedLocation == '/security')) {
            return '/home';
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (_, _) => _TrainerLogin(client: widget.client),
        ),
        GoRoute(
          path: '/security',
          builder: (context, _) => identity == null
              ? const SizedBox.shrink()
              : TrainerSecurityPage(
                  key: ValueKey('security-$identity'),
                  repository: SupabaseTrainerSecurity(widget.client, identity),
                  onComplete: () => context.go('/home'),
                  onSignOut: () => widget.client.auth.signOut(),
                ),
        ),
        ShellRoute(
          builder: (_, state, child) => TrainerShell(
            location: state.uri.path,
            child: TrainerClientNavigation.wrap(state.uri, child),
          ),
          routes: [
            GoRoute(
              path: '/assessments',
              builder: (_, _) => TrainerAssessmentsPage(
                repository: assessments(),
                access: access(),
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (_, state) => guarded(
                    state,
                    TrainerAssessmentEditorPage(repository: assessments()),
                  ),
                ),
                GoRoute(
                  path: ':id/revise',
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (_, state) => guarded(
                    state,
                    TrainerAssessmentEditorPage(
                      repository: assessments(),
                      assessmentId: state.pathParameters['id']!,
                    ),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/clients/:id/assessments',
              builder: (_, state) => TrainerClientContentRoute(
                key: ValueKey(
                  'client-content-$identity-${state.pathParameters['id']}',
                ),
                workspace: workspace(),
                assessments: assessments(),
                clientId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/clients/:id/assessments/:delivery',
              onExit: (_, state) => exits.requestExit(state.pageKey),
              builder: (_, state) => guarded(
                state,
                TrainerAssessmentDeliveryPage(
                  repository: assessments(),
                  deliveryId: state.pathParameters['delivery']!,
                ),
              ),
            ),
            GoRoute(
              path: '/recurrence',
              builder: (_, _) => TrainerRecurrencePage(
                repository: SupabaseTrainerRecurrenceRepository(
                  widget.client,
                  identity!,
                ),
                access: access(),
                workouts: workouts(),
              ),
            ),
            GoRoute(
              path: '/groups',
              builder: (_, _) => TrainerGroupsPage(
                repository: groups(),
                access: access(),
                workouts: workouts(),
                programs: programs(),
              ),
            ),
            GoRoute(
              path: '/media',
              builder: (context, _) => TrainerMediaPage(
                repository: media(),
                onOpenTechnique: () => context.push('/clients?view=technique'),
                onCreateExercise: (url) async {
                  await showTrainerExerciseEditor(
                    context,
                    SupabaseTrainerExerciseRepository(widget.client, identity!),
                    videoSource: videos,
                    mediaRepository: media(),
                    initialVideoUrl: url,
                  );
                },
              ),
            ),
            GoRoute(
              path: '/assignments/:id/technique',
              builder: (_, state) => TrainerTechniquePage(
                key: ValueKey(
                  'technique-$identity-${state.pathParameters['id']}',
                ),
                repository: media(),
                assignmentId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/clients/:id/goals',
              onExit: (_, state) => exits.requestExit(state.pageKey),
              builder: (_, state) => guarded(
                state,
                Scaffold(
                  appBar: AppBar(title: const Text('Objetivos de oposición')),
                  body: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      TrainerClientGoalsPanel(
                        key: ValueKey(
                          'client-goals-$identity-${state.pathParameters['id']}',
                        ),
                        repository: SupabaseTrainerClientGoalsRepository(
                          widget.client,
                          identity!,
                        ),
                        clientId: state.pathParameters['id']!,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            for (final view in ['results', 'technique'])
              GoRoute(
                path: '/clients/:id/$view',
                builder: (_, state) => TrainerClientWorkoutsPage(
                  key: ValueKey(
                    'client-$view-$identity-${state.pathParameters['id']}',
                  ),
                  repository: workouts(),
                  programs: programs(),
                  accessRepository: access(),
                  clientId: state.pathParameters['id']!,
                  resultsMode: view == 'results',
                  techniqueMode: view == 'technique',
                ),
              ),
            GoRoute(
              path: '/clients/:id',
              redirect: (_, state) =>
                  state.uri.queryParameters['area'] == 'goals'
                  ? '/clients/${Uri.encodeComponent(state.pathParameters['id']!)}/goals'
                  : null,
              onExit: (_, state) => exits.requestExit(state.pageKey),
              builder: (_, state) => guarded(
                state,
                TrainerClientWorkspacePage(
                  key: ValueKey(
                    'client-workspace-$identity-${state.pathParameters['id']}',
                  ),
                  repository: workspace(),
                  clientId: state.pathParameters['id']!,
                  area: state.uri.queryParameters['area'] ?? 'progress',
                ),
              ),
            ),
            GoRoute(
              path: '/clients/:id/conversation',
              onExit: (_, state) => exits.requestExit(state.pageKey),
              builder: (_, state) => guarded(
                state,
                TrainerClientConversationRoute(
                  key: ValueKey(
                    'client-conversation-$identity-${state.pathParameters['id']}',
                  ),
                  repository: workspace(),
                  clientId: state.pathParameters['id']!,
                  conversation: (relationId) => conversation(relationId),
                ),
              ),
            ),
            GoRoute(
              path: '/messages',
              builder: (_, _) => TrainerClientDirectoryPage(
                repository: access(),
                reports: false,
              ),
            ),
            GoRoute(
              path: '/reports',
              builder: (_, _) => TrainerClientDirectoryPage(
                repository: access(),
                reports: true,
              ),
            ),
            GoRoute(
              path: '/clients/:id/forms',
              builder: (_, state) => TrainerClientContentRoute(
                key: ValueKey(
                  'client-content-$identity-${state.pathParameters['id']}',
                ),
                workspace: workspace(),
                forms: forms(),
                clientId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/clients/:id/calendar',
              builder: (_, state) => TrainerSharedCalendarPage(
                key: ValueKey(
                  'shared-calendar-$identity-${state.pathParameters['id']}',
                ),
                repository: SupabaseTrainerSharedCalendarRepository(
                  widget.client,
                  identity!,
                ),
                clientId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/conversations/:id',
              onExit: (_, state) => exits.requestExit(state.pageKey),
              builder: (_, state) {
                return guarded(
                  state,
                  conversation(
                    state.pathParameters['id']!,
                    assignmentId: state.uri.queryParameters['assignment'],
                  ),
                );
              },
            ),
            GoRoute(
              path: '/settings',
              builder: (_, _) => TrainerAccountPage(
                email: widget.client.auth.currentUser?.email ?? '',
                access: access(),
                security: SupabaseTrainerSecurity(widget.client, identity!),
                onSignOut: () => widget.client.auth.signOut(),
              ),
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) => TrainerHomePage(
                access: access(),
                agenda: agenda(),
                operations: operations(),
              ),
            ),
            GoRoute(
              path: '/reviews',
              builder: (_, _) =>
                  TrainerReviewQueuePage(repository: operations()),
            ),
            GoRoute(
              path: '/assignments/:id/adapt',
              redirect: (_, state) =>
                  state.uri.queryParameters['workId'] == null
                  ? state.uri
                        .replace(
                          queryParameters: {
                            ...state.uri.queryParameters,
                            'workId': newGuidedWorkId(),
                          },
                        )
                        .toString()
                  : null,
              onExit: (_, state) => exits.requestExit(state.pageKey),
              builder: (_, state) => guarded(
                state,
                TrainerAssignmentWorkPage(
                  key: ValueKey(
                    'adapt-work-$identity-${state.pathParameters['id']}-${state.uri.queryParameters['workId']}',
                  ),
                  workId: state.uri.queryParameters['workId'],
                  repository: (review) =>
                      SupabaseTrainerAssignmentWorkRepository(
                        widget.client,
                        identity!,
                        review: review,
                      ),
                  operations: operations(),
                  workouts: workouts(),
                  assignmentId: state.pathParameters['id']!,
                  onCreateExercise: createExercise,
                  exercisePreferences: exercisePreferences,
                ),
              ),
            ),
            GoRoute(
              path: '/forms',
              builder: (_, _) =>
                  TrainerFormsPage(repository: forms(), access: access()),
              routes: [
                GoRoute(
                  path: 'new',
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (_, state) => guarded(
                    state,
                    TrainerFormEditorPage(repository: forms()),
                  ),
                ),
                GoRoute(
                  path: ':id/revise',
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (_, state) => guarded(
                    state,
                    TrainerFormEditorPage(
                      repository: forms(),
                      formId: state.pathParameters['id']!,
                    ),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/exercises',
              builder: (_, _) => TrainerExercisePage(
                key: ValueKey('trainer-exercises-$identity'),
                preferences: exercisePreferences,
                repository: SupabaseTrainerExerciseRepository(
                  widget.client,
                  identity!,
                ),
                access: access(),
                videoSource: videos,
                mediaRepository: media(),
              ),
            ),
            GoRoute(
              path: '/clients',
              builder: (context, state) => identity == null
                  ? const SizedBox.shrink()
                  : TrainerClientsPage(
                      key: ValueKey(
                        '$identity-${state.uri.queryParameters['view']}',
                      ),
                      repository: access(),
                      onSignOut: () => widget.client.auth.signOut(),
                      onOpenWorkouts: () => context.go('/workouts'),
                      onOpenClient: (id) =>
                          context.push('/clients/$id/workouts'),
                      techniqueMode:
                          state.uri.queryParameters['view'] == 'technique',
                      onOpenTechnique: (id) =>
                          context.push('/clients/$id/workouts?view=technique'),
                    ),
            ),
            GoRoute(
              path: '/agenda',
              builder: (context, _) => TrainerAgendaPage(
                repository: agenda(),
                workouts: workouts(),
                access: access(),
                assessments: assessments(),
                onMove: (assignment, date) => showTrainerMoveDialog(
                  context,
                  operations(),
                  assignment,
                  date,
                ),
                onAdapt: (assignment) async {
                  await context.push('/assignments/${assignment.id}/adapt');
                },
                onCopyWeek: (weekStart, offsetDays) async {
                  await showTrainerWeekCopyDialog(
                    context,
                    groups(),
                    weekStart,
                    offsetDays,
                  );
                },
              ),
            ),
            GoRoute(
              path: '/programs',
              builder: (_, _) => TrainerProgramLibraryPage(
                repository: programs(),
                access: access(),
                workRepository: programWorks(),
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  redirect: (_, _) => '/programs/work/${newGuidedWorkId()}',
                ),
                GoRoute(
                  path: 'work/:workId',
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (context, state) => guarded(
                    state,
                    TrainerProgramWorkPage(
                      onSaved: state.uri.queryParameters['client'] == null
                          ? null
                          : (id) {
                              context.canPop()
                                  ? context.pop(id)
                                  : context.go(
                                      '/clients/${Uri.encodeComponent(state.uri.queryParameters['client']!)}/workouts',
                                    );
                            },
                      sessionWorkRepository: sessionWorks(),
                      key: ValueKey(
                        'program-work-$identity-${state.pathParameters['workId']}',
                      ),
                      repository: programs(),
                      workouts: workouts(),
                      workRepository: programWorks(),
                      workId: state.pathParameters['workId']!,
                      initialBaseProgramId: state.uri.queryParameters['base'],
                      onCreateExercise: createExercise,
                      exercisePreferences: exercisePreferences,
                    ),
                  ),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, state) => TrainerProgramDetailPage(
                    repository: programs(),
                    workouts: workouts(),
                    programId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'revise',
                      redirect: (_, state) => Uri(
                        path: '/programs/work/${newGuidedWorkId()}',
                        queryParameters: {'base': state.pathParameters['id']!},
                      ).toString(),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/workouts',
              builder: (_, _) => TrainerWorkoutLibraryPage(
                repository: workouts(),
                accessRepository: access(),
                workRepository: sessionWorks(),
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  redirect: (_, _) => '/workouts/work/${newGuidedWorkId()}',
                ),
                GoRoute(
                  path: 'work/:workId',
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (context, state) => guarded(
                    state,
                    TrainerSessionWorkEditor(
                      key: ValueKey(
                        'session-work-$identity-${state.pathParameters['workId']}',
                      ),
                      workId: state.pathParameters['workId']!,
                      repository: sessionWorks(),
                      workouts: workouts(),
                      initialOrigin: trainerSessionWorkOrigin(
                        baseId: state.uri.queryParameters['base'],
                      ),
                      onCreateExercise: createExercise,
                      exercisePreferences: exercisePreferences,
                      onSaved: (id) async {
                        context.canPop()
                            ? context.pop(id)
                            : context.go('/workouts/$id');
                      },
                    ),
                  ),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, state) => TrainerWorkoutPreviewPage(
                    repository: workouts(),
                    templateId: state.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'revise',
                      redirect: (_, state) => Uri(
                        path: '/workouts/work/${newGuidedWorkId()}',
                        queryParameters: {'base': state.pathParameters['id']!},
                      ).toString(),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/clients/:id/workouts',
              onExit: (_, state) => exits.requestExit(state.pageKey),
              redirect: (_, state) {
                final view = state.uri.queryParameters['view'];
                if (state.uri.pathSegments.length == 3 &&
                    ['results', 'technique'].contains(view)) {
                  return '/clients/${Uri.encodeComponent(state.pathParameters['id']!)}/$view';
                }
                return null;
              },
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return guarded(
                  state,
                  TrainerClientPlanningPage(
                    key: ValueKey('client-planning-$identity-$id'),
                    clientId: id,
                    workspace: workspace(),
                    access: access(),
                    planning: SupabaseTrainerClientPlanningRepository(
                      widget.client,
                      identity!,
                    ),
                    sharedCalendar: SupabaseTrainerSharedCalendarRepository(
                      widget.client,
                      identity,
                    ),
                    workouts: workouts(),
                    programs: programs(),
                    operations: operations(),
                    goals: TrainerClientGoalsPanel(
                      key: ValueKey('planning-goals-$identity-$id'),
                      repository: SupabaseTrainerClientGoalsRepository(
                        widget.client,
                        identity,
                      ),
                      clientId: id,
                    ),
                    onCreateSession: (context) => context.push<String>(
                      '/workouts/work/${newGuidedWorkId()}',
                    ),
                    onCreateProgram: (context) => context.push<String>(
                      '/programs/work/${newGuidedWorkId()}?client=${Uri.encodeComponent(id)}',
                    ),
                  ),
                );
              },
              routes: [
                GoRoute(
                  path: ':assignment/result',
                  builder: (_, state) => TrainerWorkoutResultPage(
                    key: ValueKey(
                      'client-result-$identity-${state.pathParameters['assignment']}',
                    ),
                    repository: workouts(),
                    operations: operations(),
                    assignmentId: state.pathParameters['assignment']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    locale: const Locale('es', 'ES'),
    supportedLocales: const [Locale('es', 'ES')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    key: ValueKey(_identity),
    title: 'EntrenaOP · Preparadores',
    debugShowCheckedModeBanner: false,
    theme: EntrenaTheme.dark,
    builder: (_, child) => EntrenaInputPolicy(child: child!),
    routerConfig: _router,
  );
}

class _TrainerLogin extends StatefulWidget {
  const _TrainerLogin({required this.client});
  final SupabaseClient client;
  @override
  State<_TrainerLogin> createState() => _TrainerLoginState();
}

class _TrainerLoginState extends State<_TrainerLogin> {
  final _email = TextEditingController(), _password = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se ha podido iniciar sesión. Revisa tus datos y la conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: EntrenaWordmark(width: 190),
            ),
            const SizedBox(height: 32),
            Text(
              'Tu espacio como preparador',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Entra con tu cuenta de EntrenaOP. El acceso profesional se habilita por separado.',
            ),
            const SizedBox(height: 24),
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    onSubmitted: (_) => _login(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null) Text(_error!),
            FilledButton(
              onPressed: _busy ? null : _login,
              child: Text(_busy ? 'Entrando…' : 'Entrar'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Si necesitas crear una cuenta o recuperar tu contraseña, hazlo desde la app habitual de EntrenaOP.',
            ),
          ],
        ),
      ),
    ),
  );
}

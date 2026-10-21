import 'dart:async';

import 'package:flutter/material.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:entrena_ui/conversation_view.dart';
import 'package:trainer_access/trainer_messages.dart';

import 'trainer_clients_page.dart';
import 'trainer_security_page.dart';
import 'trainer_workout_pages.dart';
import 'trainer_workout_result.dart';
import 'trainer_workout_repository.dart';
import 'trainer_program_repository.dart';
import 'trainer_program_pages.dart';
import 'trainer_agenda_page.dart';
import 'trainer_shell.dart';
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
    SupabaseTrainerWorkoutRepository workouts() =>
        SupabaseTrainerWorkoutRepository(widget.client, identity!);
    SupabaseTrainerProgramRepository programs() =>
        SupabaseTrainerProgramRepository(widget.client, identity!);
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
        );
    Widget guarded(GoRouterState state, Widget child) => WorkflowExitScope(
      controller: exits.controller(state.pageKey),
      child: child,
    );
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
          builder: (_, state, child) =>
              TrainerShell(location: state.uri.path, child: child),
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
              builder: (_, _) => TrainerMediaPage(repository: media()),
            ),
            GoRoute(
              path: '/assignments/:id/technique',
              builder: (_, state) => TrainerTechniquePage(
                repository: media(),
                assignmentId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/clients/:id',
              onExit: (_, state) => exits.requestExit(state.pageKey),
              builder: (_, state) => guarded(
                state,
                TrainerClientWorkspacePage(
                  repository: workspace(),
                  clientId: state.pathParameters['id']!,
                ),
              ),
            ),
            GoRoute(
              path: '/clients/:id/forms',
              builder: (_, state) => TrainerClientContentRoute(
                workspace: workspace(),
                forms: forms(),
                clientId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: '/conversations/:id',
              onExit: (_, state) => exits.requestExit(state.pageKey),
              builder: (_, state) {
                final messages = SupabaseTrainerMessageRepository(
                  widget.client,
                  identity!,
                );
                final relationId = state.pathParameters['id']!;
                return guarded(
                  state,
                  ConversationView(
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
                      assignmentId: state.uri.queryParameters['assignment'],
                    ),
                    newOperationId: trainerMessageOperationId,
                    errorLabel: trainerError,
                  ),
                );
              },
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
              onExit: (_, state) => exits.requestExit(state.pageKey),
              builder: (_, state) => guarded(
                state,
                TrainerAssignmentAdaptationPage(
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
                repository: SupabaseTrainerExerciseRepository(
                  widget.client,
                  identity!,
                ),
                access: access(),
                videoSource: videos,
              ),
            ),
            GoRoute(
              path: '/clients',
              builder: (context, _) => identity == null
                  ? const SizedBox.shrink()
                  : TrainerClientsPage(
                      key: ValueKey(identity),
                      repository: access(),
                      onSignOut: () => widget.client.auth.signOut(),
                      onOpenWorkouts: () => context.go('/workouts'),
                      onOpenClient: (id) => context.push('/clients/$id'),
                    ),
            ),
            GoRoute(
              path: '/agenda',
              builder: (context, _) => TrainerAgendaPage(
                repository: agenda(),
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
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (_, state) => guarded(
                    state,
                    TrainerProgramEditorPage(
                      repository: programs(),
                      workouts: workouts(),
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
                      onExit: (_, state) => exits.requestExit(state.pageKey),
                      builder: (_, state) => guarded(
                        state,
                        TrainerProgramEditorPage(
                          repository: programs(),
                          workouts: workouts(),
                          onCreateExercise: createExercise,
                          exercisePreferences: exercisePreferences,
                          programId: state.pathParameters['id']!,
                        ),
                      ),
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
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (_, state) => guarded(
                    state,
                    TrainerWorkoutEditorPage(
                      repository: workouts(),
                      onCreateExercise: createExercise,
                      exercisePreferences: exercisePreferences,
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
                      onExit: (_, state) => exits.requestExit(state.pageKey),
                      builder: (_, state) => guarded(
                        state,
                        TrainerWorkoutEditorPage(
                          repository: workouts(),
                          onCreateExercise: createExercise,
                          exercisePreferences: exercisePreferences,
                          templateId: state.pathParameters['id']!,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/clients/:id/workouts',
              builder: (_, state) => TrainerClientWorkoutsPage(
                repository: workouts(),
                programs: programs(),
                accessRepository: access(),
                clientId: state.pathParameters['id']!,
              ),
              routes: [
                GoRoute(
                  path: ':assignment/result',
                  builder: (_, state) => TrainerWorkoutResultPage(
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

import 'trainer_invitation_landing.dart';
import 'trainer_directory_editor.dart';

import 'package:trainer_access/directory/data.dart';
import 'package:trainer_access/profile_photo/data.dart';
import 'package:trainer_access/directory/links.dart';
import 'package:trainer_access/directory/presentation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:trainer_access/trainer_invitation_link.dart';
import 'package:trainer_access/trainer_notifications.dart';
import 'package:trainer_access/trainer_appointments.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trainer_account_access.dart';
import 'trainer_account_pages.dart';
import 'trainer_auth_browser.dart';
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
import 'trainer_program_date_plan.dart';
import 'trainer_program_work_repository.dart';
import 'trainer_program_work_pages.dart';
import 'trainer_agenda_page.dart';
import 'trainer_shared_calendar_page.dart';
import 'trainer_assignment_work_page.dart';
import 'trainer_assignment_work_repository.dart';

import 'package:trainer_access/trainer_calendar.dart';

import 'trainer_shell.dart';
import 'trainer_account_page.dart';
import 'trainer_subscription_page.dart';
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
import 'trainer_self_page.dart';
import 'trainer_personal_calendar_repository.dart';

import 'package:trainer_access/authenticated_rpc.dart';

import 'trainer_client_directories.dart';
import 'trainer_client_workspace_repository.dart';
import 'trainer_client_forms_route.dart';
import 'trainer_media_repository.dart';
import 'trainer_media_page.dart';
import 'trainer_media_cleanup_repository.dart';

import 'package:entrena_ui/media_cleanup_controls.dart';

import 'trainer_technique_page.dart';
import 'trainer_recurrence_repository.dart';
import 'trainer_recurrence_page.dart';
import 'trainer_assessment_pages.dart';
import 'trainer_assessment_repository.dart';
import 'trainer_exercise_preferences_repository.dart';
import 'trainer_catalog_trash_page.dart';
import 'trainer_catalog_trash_repository.dart';

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
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );
  final accounts = SupabaseTrainerAccountAccess(
    Supabase.instance.client,
    url: TrainerConfig.url,
    publishableKey: TrainerConfig.key,
    returnUrl: Uri.parse(Uri.base.origin).replace(path: '/').toString(),
    store: PreferencesTrainerRecoveryStore(
      await SharedPreferences.getInstance(),
    ),
  );
  await accounts.initializeCallback(
    Uri.base,
    cleanUrl: clearTrainerAuthCallbackUrl,
  );
  runApp(TrainerApp(client: Supabase.instance.client, accounts: accounts));
}

class TrainerApp extends StatefulWidget {
  const TrainerApp({super.key, required this.client, this.accounts});
  final SupabaseClient client;
  final TrainerAccountAccess? accounts;
  @override
  State<TrainerApp> createState() => _TrainerAppState();
}

class _TrainerAppState extends State<TrainerApp> {
  final _appearance = ProfessionalThemeController();

  late GoRouter _router;
  late final StreamSubscription<AuthState> _subscription;
  String? _identity;
  late final TrainerAccountAccess _accounts;
  late bool _linkFailure;
  final _messageChanges = ValueNotifier<int>(0);
  String? get _currentIdentity {
    final user = widget.client.auth.currentUser;
    return user == null || user.isAnonymous ? null : user.id;
  }

  @override
  void initState() {
    super.initState();
    _accounts =
        widget.accounts ??
        SupabaseTrainerAccountAccess(
          widget.client,
          url: TrainerConfig.url,
          publishableKey: TrainerConfig.key,
          returnUrl: 'https://trainer.entrenaop.es/',
          store: MemoryTrainerRecoveryStore(),
        );
    _linkFailure = _accounts.linkFailed;
    _identity = _currentIdentity;
    _router = _createRouter();
    _subscription = widget.client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      if (event.event == AuthChangeEvent.passwordRecovery &&
          _currentIdentity != null) {
        unawaited(_accounts.rememberRecovery(_currentIdentity!));
      } else if (event.event == AuthChangeEvent.signedOut ||
          (_accounts.recoveryOwner != null &&
              _accounts.recoveryOwner != _currentIdentity)) {
        unawaited(_accounts.clearRecovery());
      }
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
    late final catalogTrashRepository = SupabaseTrainerCatalogTrashRepository(
      widget.client,
      identity!,
      cleanupAfterPurge: () async {
        await SupabaseTrainerMediaCleanupRepository(
          widget.client,
          identity,
        ).run();
      },
    );
    SupabaseTrainerWorkoutRepository workouts() => workoutRepository;
    SupabaseTrainerProgramRepository programs() => programRepository;
    SupabaseTrainerProgramWorkRepository programWorks() =>
        programWorkRepository;
    SupabaseTrainerWorkoutWorkRepository sessionWorks() =>
        sessionWorkRepository;
    SupabaseTrainerRepository access() =>
        SupabaseTrainerRepository(widget.client, userId: identity!);
    SupabaseProfilePhotoRepository photos() =>
        SupabaseProfilePhotoRepository(widget.client, ownerId: identity!);
    SupabaseDirectoryRepository directory({bool webOnly = false}) =>
        SupabaseDirectoryRepository(
          widget.client,
          owner: identity,
          webOnly: webOnly,
        );
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
    late final messages = SupabaseTrainerMessageRepository(
      widget.client,
      identity!,
    );
    Widget conversation(String relationId, {String? assignmentId}) {
      final acknowledged = <String>{};
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
        refreshInterval: const Duration(seconds: 15),
        onDisplayed: (rows) async {
          final incoming = rows
              .where((row) => !row.mine && !acknowledged.contains(row.id))
              .map((row) => row.id)
              .toList();
          if (incoming.isEmpty) return;
          await messages.markRead(incoming);
          acknowledged.addAll(incoming);
          if (mounted && _identity == identity) _messageChanges.value++;
        },
        newOperationId: trainerMessageOperationId,
        errorLabel: trainerError,
      );
    }

    return GoRouter(
      initialLocation: _linkFailure
          ? '/link-error'
          : _accounts.recovering
          ? '/update-password'
          : identity == null
          ? '/login'
          : '/home',
      redirect: (_, state) async {
        final location = state.matchedLocation;
        if (location == '/invite' ||
            location == '/directory' ||
            location.startsWith('/directory/')) {
          return null;
        }
        const public = {
          '/login',
          '/register',
          '/forgot-password',
          '/confirm-email',
          '/link-error',
        };
        if (_identity == null) {
          return public.contains(location) ? null : '/login';
        }
        if (location == '/link-error') return null;
        if (_accounts.recovering) {
          try {
            final needsMfa = await _accounts.recoveryNeedsMfa();
            final assured =
                !needsMfa ||
                await SupabaseTrainerSecurity(
                  widget.client,
                  identity!,
                ).assured();
            if (_identity != identity) return '/login';
            if (!assured) return location == '/security' ? null : '/security';
            return location == '/update-password' ? null : '/update-password';
          } catch (_) {
            return location == '/link-error' ? null : '/link-error';
          }
        }
        if (location == '/update-password') return '/account';
        if (location == '/account') return null;
        // La contratación propia y su MFA no exponen datos profesionales.
        // Permiten comprar antes de tener habilitado el panel.
        if (location == '/subscription' ||
            (location == '/security' &&
                state.uri.queryParameters['next'] == 'subscription')) {
          return null;
        }
        try {
          final status = await _accounts.status();
          if (_identity != identity) return '/login';
          if (!status.professionalAccount) return '/account';
        } catch (_) {
          return '/account';
        }
        bool assured;
        try {
          assured = await SupabaseTrainerSecurity(
            widget.client,
            identity!,
          ).assured();
        } catch (_) {
          assured = false;
        }
        if (_identity != identity) return '/login';
        if (!assured && location != '/security') return '/security';
        if (assured && (public.contains(location) || location == '/security')) {
          return '/home';
        }
        return null;
      },
      routes: [
        for (final path in ['/directory', '/directory/:profileId'])
          GoRoute(
            path: path,
            builder: (_, state) {
              final repository = directory(webOnly: true);
              return TrainerDirectoryPage(
                key: ValueKey(
                  'directory-$identity-${state.pathParameters['profileId']}',
                ),
                repository: repository,
                loadPhoto: repository.photo,
                profileId: state.pathParameters['profileId'],
                onOpen: (id) => _router.push('/directory/$id'),
                onContact: (uri) =>
                    launchUrl(uri, mode: LaunchMode.externalApplication),
                publicBase: trainerDirectoryPublicBase,
              );
            },
          ),
        GoRoute(
          path: '/subscription',
          builder: (_, state) => TrainerSubscriptionPage(
            key: ValueKey('subscription-$identity'),
            repository: SupabaseTrainerSubscriptionRepository(
              widget.client,
              identity!,
            ),
            returnedFromCheckout:
                state.uri.queryParameters['checkout'] == 'returned',
          ),
        ),
        GoRoute(
          path: '/invite',
          builder: (_, state) => TrainerInvitationLanding(
            secret: TrainerInvitationLink.fromRoute(state.uri),
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => _TrainerLogin(client: widget.client),
        ),
        for (final entry in const {
          '/register': TrainerAccountForm.register,
          '/forgot-password': TrainerAccountForm.recover,
          '/confirm-email': TrainerAccountForm.confirm,
        }.entries)
          GoRoute(
            path: entry.key,
            builder: (_, _) => TrainerAccountFormPage(
              key: ValueKey('account-form-${entry.key}'),
              accounts: _accounts,
              mode: entry.value,
            ),
          ),
        GoRoute(
          path: '/account',
          builder: (_, _) => TrainerAccountPendingPage(
            key: ValueKey('account-pending-$identity'),
            accounts: _accounts,
            onSignOut: () =>
                widget.client.auth.signOut(scope: SignOutScope.local),
          ),
        ),
        GoRoute(
          path: '/update-password',
          builder: (_, _) => TrainerPasswordUpdatePage(
            key: ValueKey('password-update-$identity'),
            accounts: _accounts,
          ),
        ),
        GoRoute(
          path: '/link-error',
          builder: (context, _) => TrainerAccountFrame(
            title: 'No se ha podido completar el enlace',
            back: false,
            children: [
              const Text(
                'El enlace puede haber caducado o haberse abierto en otro navegador. Si estabas confirmando el correo, prueba a iniciar sesión: el correo puede haber quedado confirmado.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  _linkFailure = false;
                  context.go('/login');
                },
                child: const Text('Iniciar sesión'),
              ),
              TextButton(
                onPressed: () {
                  _linkFailure = false;
                  context.go('/forgot-password');
                },
                child: const Text('Solicitar otro enlace de recuperación'),
              ),
            ],
          ),
        ),
        GoRoute(
          path: '/security',
          builder: (context, state) => identity == null
              ? const SizedBox.shrink()
              : TrainerSecurityPage(
                  key: ValueKey('security-$identity'),
                  repository: SupabaseTrainerSecurity(widget.client, identity),
                  onComplete: () => context.go(
                    state.uri.queryParameters['next'] == 'subscription'
                        ? '/subscription'
                        : '/home',
                  ),
                  onSignOut: () => widget.client.auth.signOut(),
                ),
        ),
        ShellRoute(
          builder: (_, state, child) => TrainerShell(
            key: ValueKey('trainer-shell-$identity'),
            loadInbox: identity == null ? null : messages.inbox,
            messageChanges: _messageChanges,
            location: state.uri.path.startsWith('/clients/$identity')
                ? '/self'
                : state.uri.path,
            child: TrainerClientNavigation.wrap(
              state.uri,
              child,
              selfClientId: identity,
            ),
          ),
          routes: [
            GoRoute(
              path: '/directory-profile',
              onExit: (_, state) => exits.requestExit(state.pageKey),
              builder: (_, state) {
                final repository = directory();
                return guarded(
                  state,
                  TrainerDirectoryEditor(
                    key: ValueKey('directory-editor-$identity'),
                    repository: repository,
                    photo: repository.photo,
                    uploadPhoto: repository.uploadPhoto,
                    discardPhoto: repository.discardPhoto,
                    cleanupPhotoDrafts: repository.cleanupPhotoDrafts,
                  ),
                );
              },
            ),
            GoRoute(
              path: '/self',
              builder: (_, _) => TrainerSelfPage(
                key: ValueKey('self-$identity'),
                ownerId: identity!,
                ensure: () async {
                  await authenticatedTrainerRpc(
                    widget.client,
                    identity,
                    'ensure_trainer_self_client',
                    params: {'p_expected_owner': identity},
                  );
                },
              ),
            ),
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
              path: '/media/cleanup',
              onExit: (_, state) => exits.requestExit(state.pageKey),
              builder: (context, state) {
                final cleanup = SupabaseTrainerMediaCleanupRepository(
                  widget.client,
                  identity!,
                );
                return guarded(
                  state,
                  MediaCleanupView(
                    key: ValueKey('trainer-media-cleanup-$identity'),
                    ownerKey: cleanup.ownerKey,
                    inspect: cleanup.inspect,
                    sweep: cleanup.sweep,
                    run: cleanup.run,
                    deleteVideo: cleanup.deleteVideo,
                    initialVideo: state.extra is MediaCleanupVideoTarget
                        ? state.extra as MediaCleanupVideoTarget
                        : null,
                    newOperationId: trainerOperationId,
                    onBack: () =>
                        context.canPop() ? context.pop() : context.go('/media'),
                  ),
                );
              },
            ),
            GoRoute(
              path: '/media',
              builder: (context, _) => TrainerMediaPage(
                repository: media(),
                cleanupOwnerKey: identity,
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
                onVideoRead: SupabaseCoachNotificationRepository(
                  widget.client,
                  identity!,
                ).videoRead,
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
                  photoLoader: photos().download,
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
              builder: (_, state) => TrainerReviewQueuePage(
                key: ValueKey(
                  'reviews-$identity-${state.uri.queryParameters['client']}',
                ),
                repository: operations(),
                clientId: state.uri.queryParameters['client'],
              ),
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
              onExit: (_, state) => exits.requestExit(state.pageKey),
              builder: (context, state) => guarded(
                state,
                TrainerExercisePage(
                  key: ValueKey('trainer-exercises-$identity'),
                  trashOpen: state.uri.path == '/exercises/trash',
                  onCleanup: () async {
                    await context.push('/media/cleanup');
                  },
                  trashRepository: catalogTrashRepository,
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
              routes: [
                GoRoute(
                  path: 'trash',
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (context, state) => guarded(
                    state,
                    TrainerCatalogTrashPage(
                      repository: catalogTrashRepository,
                      kind: TrainerCatalogKind.exercise,
                      onCleanup: () => context.push('/media/cleanup'),
                    ),
                  ),
                ),
              ],
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
                      photoLoader: photos().download,
                      onSignOut: () => widget.client.auth.signOut(),
                      onOpenWorkouts: () => context.go('/workouts'),
                      onOpenSelf: () => context.go('/self'),
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
                key: ValueKey('agenda-$identity'),
                repository: agenda(),
                personalCalendar: SupabaseTrainerPersonalCalendarRepository(
                  widget.client,
                  identity!,
                ),
                personalClientId: identity,
                appointments: SupabaseTrainerAppointmentRepository(
                  widget.client,
                  identity,
                  forTrainer: true,
                ),
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
              builder: (_, state) => TrainerProgramLibraryPage(
                trashOpen: state.uri.path == '/programs/trash',
                repository: programs(),
                trashRepository: catalogTrashRepository,
                access: access(),
                workRepository: programWorks(),
              ),
              routes: [
                GoRoute(
                  path: 'trash',
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (_, state) => guarded(
                    state,
                    TrainerCatalogTrashPage(
                      repository: catalogTrashRepository,
                      kind: TrainerCatalogKind.program,
                    ),
                  ),
                ),
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
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (_, state) => guarded(
                    state,
                    TrainerProgramDetailPage(
                      repository: programs(),
                      trashRepository: catalogTrashRepository,
                      workouts: workouts(),
                      programId: state.pathParameters['id']!,
                    ),
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
              builder: (_, state) => TrainerWorkoutLibraryPage(
                trashOpen: state.uri.path == '/workouts/trash',
                repository: workouts(),
                trashRepository: catalogTrashRepository,
                accessRepository: access(),
                workRepository: sessionWorks(),
              ),
              routes: [
                GoRoute(
                  path: 'trash',
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (_, state) => guarded(
                    state,
                    TrainerCatalogTrashPage(
                      repository: catalogTrashRepository,
                      kind: TrainerCatalogKind.session,
                    ),
                  ),
                ),
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
                  onExit: (_, state) => exits.requestExit(state.pageKey),
                  builder: (_, state) => guarded(
                    state,
                    TrainerWorkoutPreviewPage(
                      repository: workouts(),
                      trashRepository: catalogTrashRepository,
                      templateId: state.pathParameters['id']!,
                    ),
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
                    key: ValueKey(
                      'client-planning-$identity-$id-${state.uri.queryParameters['date']}',
                    ),
                    initialDate: parseTrainerPlanningDate(
                      state.uri.queryParameters['date'],
                    ),
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
                      compact: true,
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
                    clientId: state.pathParameters['id']!,
                    reviewAllClients:
                        state.uri.queryParameters['review'] == 'all',
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
    _appearance.dispose();
    unawaited(_subscription.cancel());
    _router.dispose();
    _messageChanges.dispose();
    if (_accounts case final SupabaseTrainerAccountAccess accounts) {
      accounts.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProfessionalThemeScope(
    controller: _appearance,
    child: Builder(
      builder: (context) => MaterialApp.router(
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        key: ValueKey(_identity),
        title: 'EntrenaOP · Preparadores',
        debugShowCheckedModeBanner: false,
        theme: EntrenaTheme.light,
        darkTheme: EntrenaTheme.dark,
        themeMode: ProfessionalThemeScope.maybeOf(context)!.value,
        builder: (_, child) => EntrenaInputPolicy(child: child!),
        routerConfig: _router,
      ),
    ),
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
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error is AuthException && error.code == 'email_not_confirmed'
              ? trainerAccountError(error)
              : 'No se ha podido iniciar sesión. Revisa tus datos y la conexión.',
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
              child: EntrenaWordmark.adaptive(width: 190),
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
            TextButton(
              onPressed: _busy ? null : () => context.go('/register'),
              child: const Text('Crear cuenta'),
            ),
            TextButton(
              onPressed: _busy ? null : () => context.go('/forgot-password'),
              child: const Text('He olvidado mi contraseña'),
            ),
            TextButton(
              onPressed: _busy ? null : () => context.go('/confirm-email'),
              child: const Text('Reenviar confirmación de correo'),
            ),
          ],
        ),
      ),
    ),
  );
}

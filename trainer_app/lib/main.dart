import 'dart:async';

import 'package:flutter/material.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_clients_page.dart';
import 'trainer_security_page.dart';
import 'trainer_workout_pages.dart';
import 'trainer_workout_result.dart';
import 'trainer_workout_repository.dart';
import 'trainer_program_repository.dart';
import 'trainer_program_pages.dart';
import 'trainer_agenda_page.dart';
import 'trainer_shell.dart';

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
    Widget guarded(GoRouterState state, Widget child) => WorkflowExitScope(
      controller: exits.controller(state.pageKey),
      child: child,
    );
    return GoRouter(
      initialLocation: identity == null ? '/login' : '/clients',
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
            return '/clients';
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
                  onComplete: () => context.go('/clients'),
                  onSignOut: () => widget.client.auth.signOut(),
                ),
        ),
        ShellRoute(
          builder: (_, state, child) =>
              TrainerShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/clients',
              builder: (context, _) => identity == null
                  ? const SizedBox.shrink()
                  : TrainerClientsPage(
                      key: ValueKey(identity),
                      repository: access(),
                      onSignOut: () => widget.client.auth.signOut(),
                      onOpenWorkouts: () => context.go('/workouts'),
                      onOpenClient: (id) =>
                          context.push('/clients/$id/workouts'),
                    ),
            ),
            GoRoute(
              path: '/agenda',
              builder: (_, _) => TrainerAgendaPage(
                repository: SupabaseTrainerAgendaRepository(
                  widget.client,
                  identity!,
                ),
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
                    TrainerWorkoutEditorPage(repository: workouts()),
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

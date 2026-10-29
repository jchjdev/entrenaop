import 'features/workouts/data/admin_workout_work_repository.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/operations/data/admin_operations_repository.dart';
import 'features/operations/data/admin_error_reporter.dart';

import 'dart:async';

import 'package:trainer_access/trainer_access.dart';

import 'features/auth/data/supabase_admin_security_repository.dart';
import 'features/auth/presentation/admin_security_page.dart';

import 'features/guided_programs/data/supabase_admin_guided_work_repository.dart';
import 'features/guided_programs/data/supabase_admin_guided_trash_repository.dart';

import 'package:entrenaop_admin/features/guided_programs/data/supabase_admin_guided_repository.dart';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/auth/presentation/admin_login_page.dart';
import 'package:entrenaop_admin/core/app_config.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_video_repository.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_media_cleanup_repository.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/editorial_covers/data/program_cover_repository.dart';
import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:entrenaop_admin/features/pro_access/data/admin_pro_access_repository.dart';

import 'features/exercises/data/admin_exercise_preferences_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );
  runApp(AdminApp(client: Supabase.instance.client));
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final AdminErrorReporter _errorReporter;
  final _authChanges = ValueNotifier<int>(0);
  late GoRouter _router;
  String? _sessionUserId;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _sessionUserId = widget.client.auth.currentUser?.id;
    _router = _createRouter();
    _errorReporter = AdminErrorReporter.forClient(widget.client)
      ..attach(() {
        final path = _router.routeInformationProvider.value.uri.path.split('/');
        final section = path.length > 1 ? path[1] : '';
        return switch (section) {
          'guided-programs' => 'guided_programs',
          'history' || 'quality' || 'system' => 'operations',
          'programs' ||
          'sessions' ||
          'exercises' ||
          'warmups' ||
          'accounts' => section,
          _ => 'admin',
        };
      });
    _authSubscription = widget.client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      final nextId = event.session?.user.id;
      if (nextId != _sessionUserId) {
        final previous = _router;
        setState(() {
          _sessionUserId = nextId;
          // Cambiar de identidad descarta la pila de consulta de la cuenta
          // anterior; renovar un token de la misma cuenta conserva sus campos.
          _router = _createRouter(
            initialLocation: nextId == null ? '/login' : '/home',
          );
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
      _authChanges.value++;
    });
  }

  GoRouter _createRouter({String? initialLocation}) {
    final client = widget.client;
    final security = SupabaseAdminSecurityRepository(client);
    final cleanup = client.auth.currentUser == null
        ? null
        : SupabaseAdminMediaCleanupRepository(
            client,
            client.auth.currentUser!.id,
          );
    return createAdminRouter(
      programs: SupabaseAdminProgramRepository(client),
      workouts: SupabaseAdminWorkoutRepository(client),
      exercises: SupabaseAdminExerciseRepository(
        client,
        ownerId: client.auth.currentUser?.id,
        processMediaCleanup: cleanup?.run,
      ),
      mediaCleanup: cleanup,
      ownerKey: client.auth.currentUser?.id,
      exerciseVideos: SupabaseAdminExerciseVideoRepository(client),
      exercisePreferences: client.auth.currentUser == null
          ? null
          : SupabaseAdminExercisePreferencesRepository(
              client,
              client.auth.currentUser!.id,
            ),
      covers: SupabaseProgramCoverRepository(client),
      guidedCovers: SupabaseProgramCoverRepository(
        client,
        resource: ProgramCoverResource.guided,
      ),
      proAccess: SupabaseAdminProAccessRepository(client),
      trainers: client.auth.currentUser == null
          ? null
          : SupabaseTrainerRepository(
              client,
              userId: client.auth.currentUser!.id,
            ),
      operations: SupabaseAdminOperationsRepository(client),
      sessionWork: client.auth.currentUser == null
          ? null
          : SupabaseAdminWorkoutWorkRepository(
              client,
              client.auth.currentUser!.id,
            ),
      guided: SupabaseAdminGuidedRepository(client),
      guidedWork: SupabaseAdminGuidedWorkRepository(client),
      guidedTrash: SupabaseAdminGuidedTrashRepository(
        client,
        ownerId: client.auth.currentUser?.id,
      ),
      onSignOut: () => unawaited(client.auth.signOut()),
      authChanges: _authChanges,
      isAuthenticated: () => client.auth.currentSession != null,
      loginBuilder: (_) => AdminLoginPage(client: client),
      needsSecurity: () async {
        try {
          return (await security.status()).needsSetupOrChallenge;
        } catch (_) {
          return true;
        }
      },
      securityBuilder: (context) => AdminSecurityPage(
        repository: security,
        onComplete: () {
          _authChanges.value++;
          GoRouter.of(context).go('/home');
        },
      ),
      initialLocation: initialLocation,
    );
  }

  @override
  void dispose() {
    _errorReporter.dispose();
    unawaited(_authSubscription.cancel());
    _router.dispose();
    _authChanges.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    locale: const Locale('es', 'ES'),
    supportedLocales: const [Locale('es', 'ES')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    title: 'EntrenaOP · Administración',
    debugShowCheckedModeBanner: false,
    theme: EntrenaTheme.dark,
    builder: (context, child) => EntrenaInputPolicy(child: child!),
    routerConfig: _router,
  );
}

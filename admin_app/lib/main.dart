import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/auth/presentation/admin_login_page.dart';
import 'package:entrenaop_admin/core/app_config.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/data/program_cover_repository.dart';
import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:entrenaop_admin/features/pro_access/data/admin_pro_access_repository.dart';

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
  final _authChanges = ValueNotifier<int>(0);
  late GoRouter _router;
  String? _sessionUserId;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _sessionUserId = widget.client.auth.currentUser?.id;
    _router = _createRouter();
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
            initialLocation: nextId == null ? '/login' : '/programs',
          );
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
      _authChanges.value++;
    });
  }

  GoRouter _createRouter({String? initialLocation}) {
    final client = widget.client;
    return createAdminRouter(
      programs: SupabaseAdminProgramRepository(client),
      workouts: SupabaseAdminWorkoutRepository(client),
      exercises: SupabaseAdminExerciseRepository(client),
      covers: SupabaseProgramCoverRepository(client),
      proAccess: AppConfig.isDevelopment
          ? SupabaseAdminProAccessRepository(client)
          : null,
      onSignOut: () => unawaited(client.auth.signOut()),
      authChanges: _authChanges,
      isAuthenticated: () => client.auth.currentSession != null,
      loginBuilder: (_) => AdminLoginPage(client: client),
      initialLocation: initialLocation,
    );
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    _router.dispose();
    _authChanges.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'EntrenaOP · Administración',
    debugShowCheckedModeBanner: false,
    theme: EntrenaTheme.dark,
    routerConfig: _router,
  );
}

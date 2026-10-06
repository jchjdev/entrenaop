import 'dart:async';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/auth/presentation/admin_login_page.dart';
import 'package:entrenaop_admin/core/app_config.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/data/program_cover_repository.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_programs_page.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );
  runApp(AdminApp(client: Supabase.instance.client));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, required this.client});

  final SupabaseClient client;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EntrenaOP · Administración',
    debugShowCheckedModeBanner: false,
    theme: EntrenaTheme.dark,
    home: StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) return AdminLoginPage(client: client);
        return AdminProgramsPage(
          key: ValueKey(session.user.id),
          repository: SupabaseAdminProgramRepository(client),
          workoutRepository: SupabaseAdminWorkoutRepository(client),
          exerciseRepository: SupabaseAdminExerciseRepository(client),
          coverRepository: SupabaseProgramCoverRepository(client),
          onSignOut: () => unawaited(client.auth.signOut()),
        );
      },
    ),
  );
}

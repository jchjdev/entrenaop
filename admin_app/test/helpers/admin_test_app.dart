import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/core/admin_router.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_programs_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Los tests de navegación usan el router real; las pantallas aisladas reciben
/// un contenedor enrutable para comprobar su retorno y guard de salida.
class AdminTestApp extends StatefulWidget {
  const AdminTestApp({required this.home, this.theme, this.builder, super.key});
  final Widget home;
  final ThemeData? theme;
  final TransitionBuilder? builder;
  @override
  State<AdminTestApp> createState() => _AdminTestAppState();
}

class _AdminTestAppState extends State<AdminTestApp> {
  late final GoRouter _router;
  @override
  void initState() {
    super.initState();
    final home = widget.home;
    if (home is AdminProgramsPage) {
      _router = createAdminRouter(
        programs: home.repository,
        workouts: home.workoutRepository,
        exercises: home.exerciseRepository,
        covers: home.coverRepository,
        onSignOut: home.onSignOut,
        initialLocation: '/programs',
      );
    } else {
      final exits = WorkflowExitRegistry();
      _router = GoRouter(
        initialLocation: '/test-screen',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Pantalla anterior')),
            routes: [
              GoRoute(
                path: 'test-screen',
                onExit: (_, state) => exits.requestExit(state.pageKey),
                builder: (_, state) => WorkflowExitScope(
                  controller: exits.controller(state.pageKey),
                  child: home,
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: _router,
    theme: widget.theme,
    builder: widget.builder,
  );
}

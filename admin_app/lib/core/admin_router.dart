import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/exercises/presentation/admin_exercises_page.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/programs/domain/program_cover.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_performance_progression_lab.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_program_attempt_preview_page.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_program_detail_page.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_program_scoring_editor.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_programs_page.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_test_pass_standards_page.dart';
import 'package:entrenaop_admin/features/workouts/data/admin_workout_repository.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_program_workouts_page.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_editor_page.dart';
import 'package:entrenaop_admin/features/workouts/presentation/admin_workout_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_admin/features/pro_access/data/admin_pro_access_repository.dart';
import 'package:entrenaop_admin/features/pro_access/presentation/admin_pro_access_page.dart';

/// Las URLs contienen identidad, nunca una entidad que solo exista en `extra`.
/// Recargar resuelve el contenido mediante los repositorios actuales y sus RLS.
GoRouter createAdminRouter({
  required AdminProgramRepository programs,
  required AdminWorkoutRepository workouts,
  required AdminExerciseRepository exercises,
  required VoidCallback onSignOut,
  ProgramCoverRepository? covers,
  AdminProAccessRepository? proAccess,
  String? initialLocation,
  Listenable? authChanges,
  bool Function()? isAuthenticated,
  WidgetBuilder? loginBuilder,
}) {
  final exits = WorkflowExitRegistry();
  GoRouter.optionURLReflectsImperativeAPIs = true;

  Widget load<T>(Future<T> Function() fetch, Widget Function(T) build) =>
      _AdminRouteLoader<T>(
        fetch: () async {
          if (!await programs.hasAccess()) {
            throw const _RouteUnavailable(
              'Esta cuenta no tiene permiso de administración.',
            );
          }
          return fetch();
        },
        builder: build,
      );

  Future<AdminProgram> program(String id) async {
    final items = await programs.listPrograms();
    for (final item in items) {
      if (item.id == id) return item;
    }
    throw const _RouteUnavailable(
      'Este programa no está disponible para esta cuenta.',
    );
  }

  Widget programPage(
    GoRouterState state,
    Widget Function(AdminProgram) build,
  ) => KeyedSubtree(
    key: ValueKey(state.uri.path),
    child: load(() => program(state.pathParameters['programId']!), build),
  );

  GoRoute workflow(String path, GoRouterWidgetBuilder builder) => GoRoute(
    path: path,
    onExit: (context, state) => isAuthenticated?.call() == false
        ? true
        : exits.requestExit(state.pageKey),
    builder: (context, state) => WorkflowExitScope(
      controller: exits.controller(state.pageKey),
      child: builder(context, state),
    ),
  );

  List<RouteBase> sessionRoutes() => [
    workflow(
      'new',
      (context, state) => programOrGeneral(
        state,
        program,
        load,
        (owner) => AdminWorkoutEditorPage(program: owner, repository: workouts),
      ),
    ),
    GoRoute(
      path: ':templateId',
      builder: (context, state) => programOrGeneral(
        state,
        program,
        load,
        (owner) => load(
          () async {
            final items = owner == null
                ? await workouts.listGeneral()
                : await workouts.listForProgram(owner.id);
            for (final item in items) {
              if (item.id == state.pathParameters['templateId']) return item;
            }
            throw const _RouteUnavailable(
              'Esta sesión no está disponible en este catálogo.',
            );
          },
          (item) => AdminWorkoutPreviewPage(
            workout: item,
            repository: workouts,
            program: owner,
          ),
        ),
      ),
      routes: [
        workflow(
          'edit',
          (context, state) => programOrGeneral(
            state,
            program,
            load,
            (owner) => load(
              () async {
                final id = state.pathParameters['templateId']!;
                final items = owner == null
                    ? await workouts.listGeneral()
                    : await workouts.listForProgram(owner.id);
                if (!items.any((item) => item.id == id)) {
                  throw const _RouteUnavailable(
                    'Esta sesión no está disponible en este catálogo.',
                  );
                }
                final template = await workouts.getTemplateById(id);
                if (template == null) {
                  throw const _RouteUnavailable('No se encuentra esta sesión.');
                }
                return template;
              },
              (template) => AdminWorkoutEditorPage(
                program: owner,
                repository: workouts,
                originalTemplate: template,
                revisionId: state.pathParameters['templateId'],
              ),
            ),
          ),
        ),
      ],
    ),
  ];

  return GoRouter(
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: initialLocation != null,
    refreshListenable: authChanges,
    redirect: (context, state) {
      if (isAuthenticated == null) {
        return state.uri.path == '/' ? '/programs' : null;
      }
      if (!isAuthenticated()) {
        return state.uri.path == '/login' ? null : '/login';
      }
      return state.uri.path == '/login' || state.uri.path == '/'
          ? '/programs'
          : null;
    },
    errorBuilder: (context, state) =>
        const _RouteMessage('Esta página no existe.'),
    routes: [
      if (proAccess != null)
        GoRoute(
          path: '/development-accounts',
          builder: (_, _) => load(
            () async => proAccess,
            (repository) => AdminProAccessPage(repository: repository),
          ),
        ),
      GoRoute(path: '/', redirect: (_, _) => '/programs'),
      if (loginBuilder != null)
        GoRoute(path: '/login', builder: (context, _) => loginBuilder(context)),
      GoRoute(
        path: '/programs',
        builder: (context, state) => AdminProgramsPage(
          repository: programs,
          workoutRepository: workouts,
          exerciseRepository: exercises,
          coverRepository: covers,
          onSignOut: onSignOut,
          showDevelopmentAccounts: proAccess != null,
        ),
        routes: [
          GoRoute(
            path: ':programId',
            builder: (context, state) => programPage(
              state,
              (item) => AdminProgramDetailPage(
                program: item,
                repository: programs,
                workoutRepository: workouts,
                coverRepository: covers,
              ),
            ),
            routes: [
              GoRoute(
                path: 'sessions',
                builder: (context, state) => programPage(
                  state,
                  (item) => AdminProgramWorkoutsPage(
                    program: item,
                    repository: workouts,
                  ),
                ),
                routes: sessionRoutes(),
              ),
              GoRoute(
                path: 'simulation',
                builder: (context, state) => programPage(
                  state,
                  (item) => load(
                    () => programs.listTests(item.id),
                    (tests) => AdminProgramAttemptPreviewPage(
                      program: item,
                      tests: tests,
                      repository: programs,
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: 'tests/:testId/scale',
                builder: (context, state) => programPage(
                  state,
                  (item) => load(
                    () async {
                      final tests = await programs.listTests(item.id);
                      final rule = await programs.getScoringRule(item.id);
                      if (rule == null) {
                        throw const _RouteUnavailable(
                          'Define primero la calificación del programa.',
                        );
                      }
                      for (final test in tests) {
                        if (test.id == state.pathParameters['testId']) {
                          return (test, rule);
                        }
                      }
                      throw const _RouteUnavailable(
                        'Esta prueba no está disponible en el programa.',
                      );
                    },
                    (data) => data.$2.scoringMode == 'pass_fail'
                        ? AdminTestPassStandardsPage(
                            test: data.$1,
                            repository: programs,
                            editable: !item.enabled,
                          )
                        : AdminTestScoreBandsPage(
                            programId: item.id,
                            test: data.$1,
                            repository: programs,
                            editable: !item.enabled,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/sessions',
        builder: (context, state) => load(
          () async => true,
          (_) => AdminProgramWorkoutsPage(program: null, repository: workouts),
        ),
        routes: sessionRoutes(),
      ),
      GoRoute(
        path: '/exercises',
        builder: (context, state) => load(
          () async => true,
          (_) => AdminExercisesPage(repository: exercises),
        ),
      ),
      GoRoute(
        path: '/laboratory',
        builder: (context, state) => load(
          () async => true,
          (_) => Scaffold(
            appBar: AppBar(
              title: const Text('Laboratorio · datos simulados'),
              leading: GoRouter.of(context).canPop()
                  ? null
                  : IconButton(
                      tooltip: 'Ir a programas',
                      icon: const Icon(Icons.home_outlined),
                      onPressed: () => context.go('/programs'),
                    ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AdminPerformanceProgressionLab(repository: exercises),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget programOrGeneral(
  GoRouterState state,
  Future<AdminProgram> Function(String) fetch,
  Widget Function<T>(Future<T> Function(), Widget Function(T)) load,
  Widget Function(AdminProgram?) build,
) {
  final id = state.pathParameters['programId'];
  return KeyedSubtree(
    key: ValueKey(state.uri.path),
    child: load<AdminProgram?>(
      () async => id == null ? null : await fetch(id),
      build,
    ),
  );
}

class _RouteUnavailable implements Exception {
  const _RouteUnavailable(this.message);
  final String message;
}

class _AdminRouteLoader<T> extends StatefulWidget {
  const _AdminRouteLoader({required this.fetch, required this.builder});
  final Future<T> Function() fetch;
  final Widget Function(T) builder;
  @override
  State<_AdminRouteLoader<T>> createState() => _AdminRouteLoaderState<T>();
}

class _AdminRouteLoaderState<T> extends State<_AdminRouteLoader<T>> {
  late Future<T> _data = widget.fetch();
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        final error = snapshot.error;
        return _RouteMessage(
          error is _RouteUnavailable ? error.message : 'No se pudo cargar esta página. Revisa la conexión e inténtalo de nuevo.',
          onRetry: () => setState(() => _data = widget.fetch()),
        );
      }
      return widget.builder(snapshot.data as T);
    },
  );
}

class _RouteMessage extends StatelessWidget {
  const _RouteMessage(this.message, {this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Administración')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            OutlinedButton(
              onPressed: () => context.go('/programs'),
              child: const Text('Ir a programas'),
            ),
          ],
        ),
      ),
    ),
  );
}

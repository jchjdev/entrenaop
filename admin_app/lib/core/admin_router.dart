import 'package:workout_editor_ui/workout_editor_work.dart';

import '../features/workouts/presentation/admin_session_work_editor.dart';
import '../features/operations/presentation/admin_dashboard_page.dart';
import '../features/operations/data/admin_operations_repository.dart';
import '../features/operations/presentation/admin_operations_pages.dart';

import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_repository.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_video_repository.dart';
import 'package:entrenaop_admin/features/exercises/data/admin_exercise_trash_repository.dart';
import 'package:entrenaop_admin/features/exercises/presentation/admin_exercises_page.dart';
import 'package:entrenaop_admin/features/exercises/presentation/admin_exercise_trash_page.dart';
import 'package:entrenaop_admin/features/programs/data/admin_program_repository.dart';
import 'package:entrenaop_admin/features/editorial_covers/domain/program_cover.dart';
import 'package:entrenaop_admin/features/programs/presentation/admin_laboratory_page.dart';
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
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop_admin/features/pro_access/data/admin_pro_access_repository.dart';
import 'package:entrenaop_admin/features/pro_access/presentation/admin_pro_access_page.dart';
import 'package:entrenaop_admin/features/guided_programs/domain/admin_guided_repository.dart';
import 'package:entrenaop_admin/features/guided_programs/presentation/admin_guided_pages.dart';

import '../features/guided_programs/presentation/admin_guided_review_page.dart';

import 'admin_shell.dart';

import 'package:trainer_access/trainer_access.dart';

import '../features/trainer_access/presentation/admin_trainers_page.dart';
import '../features/guided_programs/domain/admin_guided_work.dart';
import '../features/guided_programs/domain/admin_guided_trash.dart';
import '../features/guided_programs/presentation/admin_guided_trash_page.dart';

/// Las URLs contienen identidad, nunca una entidad que solo exista en `extra`.
/// Recargar resuelve el contenido mediante los repositorios actuales y sus RLS.
GoRouter createAdminRouter({
  required AdminProgramRepository programs,
  required AdminWorkoutRepository workouts,
  required AdminExerciseRepository exercises,
  required VoidCallback onSignOut,
  ProgramCoverRepository? covers,
  ProgramCoverRepository? guidedCovers,
  AdminProAccessRepository? proAccess,
  TrainerRepository? trainers,
  AdminOperationsRepository? operations,
  WorkoutEditorWorkRepository? sessionWork,
  AdminGuidedRepository? guided,
  AdminGuidedWorkRepository? guidedWork,
  AdminGuidedTrashRepository? guidedTrash,
  AdminExerciseVideoRepository? exerciseVideos,
  ExerciseCatalogPreferences? exercisePreferences,
  Object? ownerKey,
  String? initialLocation,
  Listenable? authChanges,
  bool Function()? isAuthenticated,
  WidgetBuilder? loginBuilder,
  WidgetBuilder? securityBuilder,
  Future<bool> Function()? needsSecurity,
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

  GoRoute workflow(
    String path,
    GoRouterWidgetBuilder builder, {
    List<RouteBase> routes = const [],
    GoRouterRedirect? redirect,
  }) => GoRoute(
    path: path,
    redirect: redirect,
    onExit: (context, state) => isAuthenticated?.call() == false
        ? true
        : exits.requestExit(state.pageKey),
    builder: (context, state) => WorkflowExitScope(
      controller: exits.controller(state.pageKey),
      child: builder(context, state),
    ),
    routes: routes,
  );

  String sessionWorkLocation(GoRouterState state, {String? base}) {
    final programId = state.pathParameters['programId'];
    return Uri(
      path:
          '${programId == null ? "/sessions" : "/programs/${Uri.encodeComponent(programId)}/sessions"}/work/${newGuidedWorkId()}',
      queryParameters: {
        'new': 'true',
        'base': ?base,
        if (state.uri.queryParameters['standalone'] == 'false')
          'standalone': 'false',
        if (state.uri.queryParameters['returnId'] == 'true') 'returnId': 'true',
      },
    ).toString();
  }

  List<RouteBase> sessionRoutes() => [
    if (sessionWork != null)
      workflow(
        'work/:workId',
        (context, state) => load(
          () async => true,
          (_) => AdminSessionWorkEditor(
            key: ValueKey(state.uri.toString()),
            workId: state.pathParameters['workId']!,
            initialShowInLibrary:
                state.uri.queryParameters['standalone'] != 'false',
            repository: sessionWork,
            workouts: workouts,
            exerciseRepository: exercises,
            exerciseVideos: exerciseVideos,
            exercisePreferences: exercisePreferences,
            origin: state.uri.queryParameters['new'] == 'true'
                ? {
                    'baseId': state.uri.queryParameters['base'],
                    'programId': state.pathParameters['programId'],
                    'parentWorkId': null,
                    'phaseId': null,
                    'positionId': null,
                    'duplicate': false,
                  }
                : null,
            onSaved: (id) async {
              if (context.mounted) {
                if (context.canPop()) {
                  context.pop<Object>(
                    state.uri.queryParameters['returnId'] == 'true' ? id : true,
                  );
                } else {
                  context.go(
                    state.pathParameters['programId'] == null
                        ? '/sessions'
                        : '/programs/${Uri.encodeComponent(state.pathParameters['programId']!)}/sessions',
                  );
                }
              }
            },
          ),
        ),
      ),
    workflow(
      'new',
      (context, state) => programOrGeneral(
        state,
        program,
        load,
        (owner) => AdminWorkoutEditorPage(
          exerciseRepository: exercises,
          exerciseVideos: exerciseVideos,
          exercisePreferences: exercisePreferences,
          program: owner,
          repository: workouts,
          initialShowInLibrary:
              state.uri.queryParameters['standalone'] != 'false',
          returnSavedId:
              owner == null && state.uri.queryParameters['returnId'] == 'true',
        ),
      ),
      redirect: sessionWork == null
          ? null
          : (_, state) => sessionWorkLocation(state),
    ),
    workflow(
      ':templateId',
      (context, state) => programOrGeneral(
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
            returnSavedId: state.uri.queryParameters['returnId'] == 'true',
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
                exerciseRepository: exercises,
                exerciseVideos: exerciseVideos,
                exercisePreferences: exercisePreferences,
                program: owner,
                repository: workouts,
                originalTemplate: template,
                revisionId: state.pathParameters['templateId'],
                returnSavedId:
                    owner == null &&
                    state.uri.queryParameters['returnId'] == 'true',
              ),
            ),
          ),
          redirect: sessionWork == null
              ? null
              : (_, state) => sessionWorkLocation(
                  state,
                  base: state.pathParameters['templateId'],
                ),
        ),
      ],
    ),
  ];

  return GoRouter(
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: initialLocation != null,
    refreshListenable: authChanges,
    redirect: (context, state) async {
      if (isAuthenticated == null) {
        return state.uri.path == '/'
            ? (operations == null ? '/programs' : '/home')
            : null;
      }
      if (!isAuthenticated()) {
        return state.uri.path == '/login' ? null : '/login';
      }
      if (securityBuilder != null &&
          state.uri.path != '/security' &&
          await needsSecurity!()) {
        return '/security';
      }
      return state.uri.path == '/login' || state.uri.path == '/'
          ? (operations == null ? '/programs' : '/home')
          : null;
    },
    errorBuilder: (context, state) =>
        const _RouteMessage('Esta página no existe.'),
    routes: [
      if (loginBuilder != null)
        GoRoute(path: '/login', builder: (context, _) => loginBuilder(context)),
      if (securityBuilder != null)
        GoRoute(
          path: '/security',
          builder: (context, _) => securityBuilder(context),
        ),
      ShellRoute(
        builder: (_, state, child) => AdminShell(
          path: state.uri.path,
          hasAccess: programs.hasAccess,
          canManageAccounts: proAccess?.canManageAccounts,
          hasGuidedPrograms: guided != null,
          hasOperations: operations != null,
          onSignOut: onSignOut,
          child: child,
        ),
        routes: [
          if (operations != null) ...[
            GoRoute(
              path: '/home',
              builder: (_, _) => load(
                () async => true,
                (_) => AdminDashboardPage(
                  operations: operations,
                  sessions: sessionWork,
                  programs: guidedWork,
                ),
              ),
            ),
            GoRoute(
              path: '/history',
              builder: (_, _) => load(
                () async => operations,
                (repo) => AdminHistoryPage(repository: repo),
              ),
              routes: [
                workflow(
                  ':eventId',
                  (_, state) => load(
                    () async {
                      final id = int.tryParse(state.pathParameters['eventId']!);
                      if (id == null || id < 1) {
                        throw const _RouteUnavailable(
                          'El identificador del cambio no es válido.',
                        );
                      }
                      return (operations, id);
                    },
                    (data) => AdminHistoryDetailPage(
                      repository: data.$1,
                      eventId: data.$2,
                    ),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/quality',
              builder: (_, _) => load(
                () async => operations,
                (repo) => AdminQualityPage(repository: repo),
              ),
            ),
            GoRoute(
              path: '/system',
              builder: (_, _) => load(
                () async => operations,
                (repo) => AdminSystemPage(repository: repo),
              ),
            ),
          ],
          if (guided != null)
            GoRoute(
              path: '/guided-programs',
              builder: (_, state) => KeyedSubtree(
                key: ValueKey(state.uri.toString()),
                child: load(
                  () async => true,
                  (_) => AdminGuidedCatalogPage(
                    repository: guided,
                    covers: guidedCovers,
                    workRepository: guidedWork,
                    trashRepository: guidedTrash,
                  ),
                ),
              ),
              routes: [
                if (guidedTrash != null)
                  workflow(
                    'trash',
                    (_, _) => load(
                      () async => true,
                      (_) => AdminGuidedTrashPage(
                        repository: guidedTrash,
                        ownerKey: ownerKey,
                      ),
                    ),
                  ),
                if (guidedWork != null)
                  workflow(
                    'work/:workId',
                    (context, state) => KeyedSubtree(
                      key: ValueKey(state.uri.toString()),
                      child: load(
                        () async {
                          final id = state.pathParameters['workId']!;
                          final work =
                              await guidedWork.load(id) ??
                              GuidedWork(
                                id: id,
                                state: const {},
                                baseProgramId:
                                    state.uri.queryParameters['base'],
                              );
                          if (work.permanentlyDeleted) {
                            throw const _RouteUnavailable(
                              'Este trabajo se ha borrado definitivamente. Vuelve a Programas guiados para crear otro.',
                            );
                          }
                          if (work.discarded) {
                            throw const _RouteUnavailable(
                              'Este trabajo o su programa de origen están en la papelera. Recupéralo desde Programas guiados → Papelera.',
                            );
                          }
                          final base = work.baseProgramId;
                          return (
                            work,
                            base == null ? null : await guided.program(base),
                          );
                        },
                        (data) => data.$1.finalizedProgramId != null
                            ? Scaffold(
                                body: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Este trabajo ya se guardó en el catálogo.',
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            context.go('/guided-programs'),
                                        child: const Text('Ver programas'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : AdminGuidedEditorPage(
                                sessionWorkRepository: sessionWork,
                                exerciseRepository: exercises,
                                exerciseVideos: exerciseVideos,
                                exercisePreferences: exercisePreferences,
                                repository: guided,
                                workouts: workouts,
                                original: data.$2,
                                workRepository: guidedWork,
                                work: data.$1,
                              ),
                      ),
                    ),
                  ),
                workflow(
                  'new',
                  (_, _) => load(
                    () async => true,
                    (_) => AdminGuidedEditorPage(
                      sessionWorkRepository: sessionWork,
                      exerciseRepository: exercises,
                      exerciseVideos: exerciseVideos,
                      exercisePreferences: exercisePreferences,
                      repository: guided,
                      workouts: workouts,
                    ),
                  ),
                  redirect: guidedWork == null
                      ? null
                      : (_, _) => '/guided-programs/work/${newGuidedWorkId()}',
                ),
                workflow(
                  ':guidedId/review',
                  (_, state) => load(
                    () async => true,
                    (_) => AdminGuidedReviewPage(
                      programId: state.pathParameters['guidedId']!,
                      repository: guided,
                      workouts: workouts,
                      covers: guidedCovers,
                    ),
                  ),
                ),
                workflow(
                  ':guidedId/edit',
                  (_, state) => load(
                    () => guided.program(state.pathParameters['guidedId']!),
                    (p) => AdminGuidedEditorPage(
                      sessionWorkRepository: sessionWork,
                      exerciseRepository: exercises,
                      exerciseVideos: exerciseVideos,
                      exercisePreferences: exercisePreferences,
                      repository: guided,
                      workouts: workouts,
                      original: p,
                    ),
                  ),
                  redirect: guidedWork == null
                      ? null
                      : (_, state) =>
                            '/guided-programs/work/${newGuidedWorkId()}?base=${state.pathParameters['guidedId']}',
                ),
              ],
            ),
          if (guided != null)
            GoRoute(
              path: '/warmups',
              builder: (_, _) => load(
                () async => true,
                (_) =>
                    AdminGuidedCatalogPage(repository: guided, warmups: true),
              ),
              routes: [
                workflow(
                  'new',
                  (_, state) => load(
                    () async => true,
                    (_) => AdminWorkoutEditorPage(
                      exerciseRepository: exercises,
                      exerciseVideos: exerciseVideos,
                      exercisePreferences: exercisePreferences,
                      program: null,
                      repository: workouts,
                      warmup: true,
                      returnSavedId:
                          state.uri.queryParameters['returnId'] == 'true',
                      saveInput: (input) => guided.saveWarmup(input),
                    ),
                  ),
                ),
                workflow(
                  ':warmupId/edit',
                  (_, state) => load(
                    () async {
                      final id = state.pathParameters['warmupId']!;
                      final warmup = (await guided.warmups())
                          .where((w) => w.id == id)
                          .first;
                      final template = await workouts.getTemplateById(
                        warmup.templateId,
                      );
                      if (template == null) {
                        throw const _RouteUnavailable(
                          'No se encuentra el calentamiento.',
                        );
                      }
                      return (warmup, template);
                    },
                    (data) => AdminWorkoutEditorPage(
                      exerciseRepository: exercises,
                      exerciseVideos: exerciseVideos,
                      exercisePreferences: exercisePreferences,
                      program: null,
                      repository: workouts,
                      warmup: true,
                      originalTemplate: data.$2,
                      saveInput: (input) =>
                          guided.saveWarmup(input, previousId: data.$1.id),
                    ),
                  ),
                ),
              ],
            ),
          if (proAccess != null)
            GoRoute(
              path: '/accounts',
              builder: (_, _) => load(
                () async {
                  if (!await proAccess.canManageAccounts()) {
                    throw const _RouteUnavailable(
                      'Solo el responsable de cuentas puede gestionar Cuentas y Pro.',
                    );
                  }
                  return proAccess;
                },
                (repository) => AdminProAccessPage(
                  repository: repository,
                  operations: operations,
                  trainers: trainers,
                ),
              ),
            ),
          if (proAccess != null)
            GoRoute(
              path: '/development-accounts',
              redirect: (_, _) => '/accounts',
            ),
          GoRoute(path: '/', redirect: (_, _) => '/programs'),
          GoRoute(
            path: '/programs',
            builder: (context, state) => AdminProgramsPage(
              repository: programs,
              workoutRepository: workouts,
              exerciseRepository: exercises,
              coverRepository: covers,
              onSignOut: onSignOut,
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
                        workRepository: sessionWork,
                        program: item,
                        repository: workouts,
                        trashRepository: guidedTrash,
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
          if (trainers != null && proAccess != null)
            GoRoute(
              path: '/trainers',
              builder: (_, _) => load(() async {
                if (!await proAccess.canManageAccounts()) {
                  throw const _RouteUnavailable(
                    'Solo el responsable de cuentas puede gestionar entrenadores.',
                  );
                }
                return trainers;
              }, (repository) => AdminTrainersPage(repository: repository)),
            ),
          GoRoute(
            path: '/sessions',
            builder: (context, state) => load(
              () async => true,
              (_) => AdminProgramWorkoutsPage(
                workRepository: sessionWork,
                program: null,
                repository: workouts,
                trashRepository: guidedTrash,
              ),
            ),
            routes: [
              if (guidedTrash != null)
                workflow(
                  'trash',
                  (context, state) => load(
                    () async => true,
                    (_) => AdminGuidedTrashPage(
                      repository: guidedTrash,
                      sessions: true,
                      ownerKey: ownerKey,
                    ),
                  ),
                ),
              ...sessionRoutes(),
            ],
          ),
          workflow(
            '/exercises',
            (context, state) => load(
              () async => true,
              (_) => AdminExercisesPage(
                preferences: exercisePreferences,
                key: ValueKey(state.uri.toString()),
                initialExerciseId: state.uri.queryParameters['edit'],
                repository: exercises,
                videos: exerciseVideos,
                ownerKey: ownerKey,
              ),
            ),
            routes: [
              workflow(
                'trash',
                (_, _) => load(
                  () async {
                    if (exercises is! AdminExerciseTrashRepository) {
                      throw const _RouteUnavailable(
                        'La papelera de ejercicios no está disponible.',
                      );
                    }
                    return exercises as AdminExerciseTrashRepository;
                  },
                  (repository) => AdminExerciseTrashPage(
                    repository: repository,
                    ownerKey: ownerKey,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/laboratory',
            builder: (context, state) => load(
              () async => true,
              (_) => AdminLaboratoryPage(repository: exercises),
            ),
            routes: [
              GoRoute(
                path: 'push-ups',
                builder: (_, _) => load(
                  () async => true,
                  (_) =>
                      AdminLaboratoryPage(repository: exercises, pushUps: true),
                ),
              ),
            ],
          ),
        ],
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

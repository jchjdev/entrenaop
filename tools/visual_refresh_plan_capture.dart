// Capturas de widgets actuales con datos simulados; no usa cuentas ni red.
import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/presentation/pages/home_page.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/repositories/home_favorites_repository.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_goal.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/preparation_program.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_hub_page.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'visual_atlas_capture.dart';

void main() {
  atlasSource = 'tools/visual_refresh_plan_capture.dart';
  for (final (route, status, width, title) in [
    ('/plan', 'training', 390.0, 'Mi plan en curso móvil'),
    ('/plan', 'training', 1280.0, 'Mi plan en curso escritorio'),
    ('/plan', 'needs_review', 390.0, 'Mi plan revisión pendiente'),
    ('/plan', 'paused', 390.0, 'Mi plan pausado'),
    ('/plan', 'new', 390.0, 'Mi plan primer acceso'),
    ('/plan', 'failure', 390.0, 'Mi plan error conservado'),
    ('/home', 'training', 390.0, 'Inicio sesión actual'),
    ('/home', 'needs_review', 390.0, 'Inicio revisión pendiente'),
  ]) {
    atlasTestWidgets(title, (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = _Overview(_data(status));
      final cubit = DashboardCubit(getOverview: source);
      addTearDown(cubit.close);
      await cubit.load();
      if (status == 'failure') {
        source.fail = true;
        await cubit.load();
      }
      final router = GoRouter(
        initialLocation: route,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => AppShell(navigationShell: shell),
            branches: [
              for (final path in [
                '/home',
                '/plan',
                '/library',
                '/assessment/history',
                '/profile',
              ])
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: path,
                      builder: (_, _) => BlocProvider.value(
                        value: cubit,
                        child: path == '/plan'
                            ? const TrainingHubPage()
                            : path == '/home'
                            ? HomePage(
                                favoritesRepository: _Favorites(),
                                userId: 'fixture',
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await atlasPumpWidget(
        tester,
        MaterialApp.router(
          // El runner utiliza Ahem cuando el estilo no indica familia.
          // Se normaliza solo la fuente de esa etiqueta, igual que Roboto
          // en el resto de capturas; estructura y estilos de la app intactos.
          theme: EntrenaTheme.dark.copyWith(
            navigationRailTheme: EntrenaTheme.dark.navigationRailTheme.copyWith(
              selectedLabelTextStyle: EntrenaTheme
                  .dark
                  .navigationRailTheme
                  .selectedLabelTextStyle
                  ?.copyWith(fontFamily: 'Roboto'),
            ),
          ),
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      );
      await atlasSettle(tester);
      if (route == '/plan') {
        await tester.ensureVisible(find.text('Pendientes de esta semana'));
        await atlasSettle(tester);
        await tester.ensureVisible(
          find.text('Editar disponibilidad y material'),
        );
        await atlasSettle(tester);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

PreparationOverview _data(String status) {
  final today = DateUtils.dateOnly(DateTime.now());
  final week = today.subtract(Duration(days: today.weekday - 1));
  const current = PreparationGoal(
    id: 'current',
    program: PreparationProgram(
      id: 'fas',
      name: 'Mejora FAS',
      kind: PreparationProgramKind.internalAssessment,
    ),
  );
  const paused = PreparationGoal(
    id: 'paused',
    program: PreparationProgram(
      id: 'tropa',
      name: 'Ingreso a Tropa y Marinería',
      kind: PreparationProgramKind.internalAssessment,
    ),
  );
  final state = status == 'failure' ? 'training' : status;
  return PreparationOverview(
    assessments: const [],
    preferences: null,
    goals: state == 'new' ? const [] : const [current, paused],
    weekStart: week,
    programs: state == 'new'
        ? const []
        : [
            AdaptiveProgramProgress(
              goalId: 'current',
              name: 'Mejora FAS',
              status: state,
              message: state == 'training'
                  ? 'Tu programa continúa con los resultados que registras.'
                  : state == 'needs_review'
                  ? 'Confirma tu disponibilidad actual para continuar.'
                  : 'Tu historial se conserva. Revisa tu contexto antes de retomar.',
            ),
            const AdaptiveProgramProgress(
              goalId: 'paused',
              name: 'Ingreso a Tropa y Marinería',
              status: 'draft',
              message: 'Pendiente de configurar.',
            ),
          ],
    weeklyWorkouts: state == 'training'
        ? [
            ScheduledWorkout(
              id: 'session',
              templateId: 'template',
              templateName: 'Carrera y fuerza · Sesión 2',
              templateVersion: 1,
              scheduledDate: today,
              source: ScheduledWorkoutSource.algorithm,
              status: ScheduledWorkoutStatus.planned,
              preparationGoalId: 'current',
              estimatedDurationMinutes: 45,
            ),
            ScheduledWorkout(
              id: 'completed',
              templateId: 'template',
              templateName: 'Sesión completada',
              templateVersion: 1,
              scheduledDate: week,
              source: ScheduledWorkoutSource.algorithm,
              status: ScheduledWorkoutStatus.completed,
              preparationGoalId: 'current',
            ),
          ]
        : const [],
  );
}

class _Overview implements GetPreparationOverviewUseCase {
  _Overview(this.data);
  final PreparationOverview data;
  bool fail = false;
  @override
  Future<PreparationOverview> call() async {
    if (fail) throw StateError('offline');
    return data;
  }
}

class _Favorites implements HomeFavoritesRepository {
  @override
  Future<List<HomeShortcut>> load(String userId) async => [];
  @override
  Future<void> save(String userId, List<HomeShortcut> favorites) async {}
}

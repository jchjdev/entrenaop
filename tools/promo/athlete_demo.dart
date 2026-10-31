// Entrada local para filmación: widgets de producto y datos solo en memoria.
// No inicializa Supabase, notificaciones, compras ni cuentas reales.
import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/core/theme/entrena_theme.dart';
import 'package:entrenaop/features/auth/presentation/pages/home_page.dart';
import 'package:entrenaop/features/dashboard/domain/entities/preparation_overview.dart';
import 'package:entrenaop/features/dashboard/domain/repositories/home_favorites_repository.dart';
import 'package:entrenaop/features/dashboard/domain/usecases/get_preparation_overview_usecase.dart';
import 'package:entrenaop/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/repositories/exercise_repository.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercises_usecase.dart';
import 'package:entrenaop/features/exercises/presentation/bloc/exercise_library_cubit.dart';
import 'package:entrenaop/features/exercises/presentation/pages/exercise_library_page.dart';
import 'package:entrenaop/features/library/presentation/library_hub_page.dart';
import 'package:entrenaop/features/physical_assessment/presentation/pages/preparation_marks_page.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/adaptive_program_progress.dart';
import 'package:entrenaop/features/preparation_goal/domain/repositories/preparation_training_repository.dart';
import 'package:entrenaop/features/training_plan/presentation/pages/training_hub_page.dart';
import 'package:entrenaop/features/trainers/domain/student_notice_repository.dart';
import 'package:entrenaop/features/trainers/presentation/pages/professional_hub_page.dart';
import 'package:entrenaop/features/trainers/presentation/student_navigation.dart';
import 'package:entrenaop/features/workout_schedule/domain/entities/scheduled_workout.dart';
import 'package:entrenaop/features/workout_schedule/domain/repositories/workout_schedule_repository.dart';
import 'package:entrenaop/features/workout_schedule/domain/usecases/workout_schedule_usecases.dart';
import 'package:entrenaop/features/workout_schedule/presentation/bloc/workout_schedule_cubit.dart';
import 'package:entrenaop/features/workout_schedule/presentation/pages/workout_schedule_page.dart';
import 'package:entrenaop/features/workouts/domain/entities/workout_template.dart';
import 'package:entrenaop/features/workouts/domain/repositories/workout_repository.dart';
import 'package:entrenaop/features/workouts/domain/usecases/get_starter_workout_usecase.dart';
import 'package:entrena_ui/conversation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../test/helpers/measurement_comparison_fixtures.dart';
import 'scenario.dart';

void main() => runApp(const AthleteDemo());

class AthleteDemo extends StatefulWidget {
  const AthleteDemo({super.key});
  @override
  State<AthleteDemo> createState() => AthleteDemoState();
}

class AthleteDemoState extends State<AthleteDemo> {
  final notices = DemoNotices();
  final overview = DemoOverview();
  late final dashboard = DashboardCubit(getOverview: overview)..load();
  late final navigation = StudentNavigationController(
    loadSnapshot: notices.snapshot,
    loadHasRelationship: () async => true,
  )..refresh();
  late final exercises = ExerciseLibraryCubit(
    getExercises: GetExercisesUseCase(DemoExercises()),
    userId: demoStudents.first.id,
  )..load();
  late final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => StudentNavigationScope(
          controller: navigation,
          child: AppShell(navigationShell: shell),
        ),
        branches: [
          for (final path in [
            '/home',
            '/plan',
            '/library',
            '/assessment/history',
            '/my-trainer',
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (_, state) => switch (path) {
                    '/home' => BlocProvider.value(
                      value: dashboard,
                      child: HomePage(
                        favoritesRepository: DemoFavorites(),
                        userId: demoStudents.first.id,
                      ),
                    ),
                    '/plan' => BlocProvider.value(
                      value: dashboard,
                      child: const TrainingHubPage(),
                    ),
                    '/library' => const LibraryHubPage(),
                    '/assessment/history' => PreparationMarksPage(
                      goalId: 'troop',
                      load: (_) async => demoMarksData(),
                    ),
                    _ => ProfessionalHubPage(
                      repository: notices,
                      userId: demoStudents.first.id,
                      focusNotices:
                          state.uri.queryParameters['view'] == 'notices',
                    ),
                  },
                  routes: [
                    if (path == '/plan')
                      GoRoute(
                        path: 'week',
                        builder: (_, _) => BlocProvider(
                          create: (_) => createSchedule(overview)..load(),
                          child: const WorkoutSchedulePage(),
                        ),
                      ),
                    if (path == '/library')
                      GoRoute(
                        path: 'exercises',
                        builder: (_, _) => BlocProvider.value(
                          value: exercises,
                          child: const ExerciseLibraryPage(),
                        ),
                      ),
                    if (path == '/my-trainer')
                      GoRoute(
                        path: 'conversations/:id',
                        builder: (_, _) => demoConversation(),
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ],
    // Los enlaces fuera del rodaje quedan contenidos en esta demo aislada.
    errorBuilder: (_, _) => Scaffold(
      appBar: AppBar(title: const Text('Demo local')),
      body: const Center(
        child: Text('Esta pantalla no forma parte del recorrido de grabación.'),
      ),
    ),
  );

  @override
  void dispose() {
    router.dispose();
    navigation.dispose();
    dashboard.close();
    exercises.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: EntrenaTheme.dark,
    routerConfig: router,
  );
}

Widget demoConversation() => ConversationView(
  header: () async =>
      const ConversationHeader(title: 'Entrenador demo', canSend: true),
  load: (_) async => [
    ConversationEntry(
      id: 'message-1',
      body: 'He terminado la sesión de hoy. Buenas sensaciones en la carrera.',
      createdAt: demoToday.add(const Duration(hours: 10)),
      mine: true,
    ),
    ConversationEntry(
      id: 'message-2',
      body: '¡Buen trabajo, Lucía! He revisado tus registros. Tienes la próxima sesión en tu semana.',
      createdAt: demoToday.add(const Duration(hours: 10, minutes: 5)),
      mine: false,
    ),
  ],
  send: (_, _) async {},
  newOperationId: () => 'local-demo',
  errorLabel: (_) => 'Demo local',
);

class DemoOverview implements GetPreparationOverviewUseCase {
  final week = demoToday.subtract(Duration(days: demoToday.weekday - 1));
  late final workouts = [
    for (var i = 0; i < 4; i++)
      ScheduledWorkout(
        id: 'session-$i',
        templateId: 'template-$i',
        templateName: [
          'Fuerza · Tren superior',
          'Carrera · Ritmo cómodo',
          'Fuerza y movilidad',
          'Carrera · Cambios de ritmo',
        ][i],
        templateVersion: 1,
        scheduledDate: i == 2 ? demoToday : week.add(Duration(days: i * 2)),
        source: ScheduledWorkoutSource.coach,
        coachName: 'Entrenador demo',
        status: i < 2
            ? ScheduledWorkoutStatus.completed
            : ScheduledWorkoutStatus.planned,
        preparationGoalId: 'troop',
        estimatedDurationMinutes: [40, 35, 45, 30][i],
      ),
  ];
  @override
  Future<PreparationOverview> call() async => PreparationOverview(
    assessments: const [],
    preferences: null,
    goals: [comparisonMarksData().goal],
    weekStart: week,
    weeklyWorkouts: workouts,
    programs: const [
      AdaptiveProgramProgress(
        goalId: 'troop',
        name: 'Preparación física',
        status: 'training',
        message: 'Tu preparación, sesión a sesión.',
      ),
    ],
  );
}

PreparationMarksData demoMarksData() => PreparationMarksData(
  goal: comparisonMarksData().goal,
  troop: [
    comparisonAssessment(
      day: 30,
      pushUps: 24,
      category: AssessmentCategory.women,
    ),
    comparisonAssessment(
      day: 16,
      pushUps: 22,
      run: 550000,
      category: AssessmentCategory.women,
    ),
  ],
  running: comparisonMarksData().running,
);

class DemoFavorites implements HomeFavoritesRepository {
  List<HomeShortcut> values = [];
  @override
  Future<List<HomeShortcut>> load(String userId) async => values;
  @override
  Future<void> save(String userId, List<HomeShortcut> favorites) async =>
      values = favorites;
}

class DemoNotices extends StudentNoticeRepository {
  final read = <String>{};
  @override
  Future<StudentNoticeSnapshot> snapshot({
    StudentNotice? before,
    StudentNoticeKind? kind,
  }) async {
    final items = [
      StudentNotice(
        id: 'message',
        kind: StudentNoticeKind.message,
        title: 'Tu preparador ha revisado la sesión',
        trainerName: 'Entrenador demo',
        createdAt: demoToday,
        readAt: read.contains('message') ? demoToday : null,
      ),
      StudentNotice(
        id: 'week',
        kind: StudentNoticeKind.assignment,
        title: 'Tu próxima sesión ya está en la semana',
        trainerName: 'Entrenador demo',
        createdAt: demoToday,
        readAt: read.contains('week') ? demoToday : null,
      ),
    ];
    return StudentNoticeSnapshot(
      items: items.where((i) => kind == null || i.kind == kind).toList(),
      hasMore: false,
      unreadCount: items.where((i) => i.readAt == null).length,
      resources: const StudentNoticeResources(
        hasForms: true,
        hasAssessments: true,
        hasConversations: true,
        hasTechnique: true,
        hasAssignedWorkouts: true,
        conversationRelationId: 'demo-relation',
        conversations: [
          StudentConversationLink('demo-relation', 'Entrenador demo'),
        ],
      ),
    );
  }

  @override
  Future<void> ack(String noticeId, {int? generation}) async {
    read.add(noticeId);
  }

  @override
  Future<StudentNoticeTarget?> resolve(
    String noticeId, {
    int? generation,
  }) async => noticeId == 'message'
      ? const StudentNoticeTarget(
          kind: StudentNoticeTargetKind.conversation,
          targetId: 'demo-relation',
        )
      : StudentNoticeTarget(
          kind: StudentNoticeTargetKind.workout,
          targetId: 'session-2',
          scheduledDate: demoToday,
        );
  @override
  Future<TechniqueTargetPage> listTechnique({TechniqueTarget? before}) async =>
      const TechniqueTargetPage(items: [], hasMore: false);
}

class DemoExercises implements ExerciseRepository {
  @override
  Future<List<ExerciseEntity>> getExercises() async => [
    for (final (id, name, muscle, equipment) in [
      ('pull', 'Dominadas', 'espalda', 'barra'),
      ('push', 'Flexiones', 'pecho', 'peso corporal'),
      ('squat', 'Sentadilla', 'piernas', 'barra'),
      ('row', 'Remo con mancuerna', 'espalda', 'mancuerna'),
      ('plank', 'Plancha isométrica', 'core', 'peso corporal'),
    ])
      ExerciseEntity(
        id: id,
        name: name,
        description: 'Controla el movimiento y mantén una técnica estable.',
        muscleGroups: [muscle],
        equipment: [equipment],
        difficulty: 'intermedio',
        exerciseType: 'repeticiones',
        isPublic: true,
        origin: ExerciseOrigin.system,
      ),
  ];
  // La filmación solo lee el catálogo; otras operaciones no acceden a servicios.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Fuera del recorrido de demo: ${invocation.memberName}',
  );
}

WorkoutScheduleCubit createSchedule(DemoOverview overview) {
  final schedule = DemoSchedule(overview.workouts);
  final templates = DemoTemplates();
  return WorkoutScheduleCubit(
    getSchedule: GetWorkoutScheduleUseCase(schedule),
    scheduleWorkout: ScheduleWorkoutUseCase(schedule),
    rescheduleWorkout: RescheduleWorkoutUseCase(schedule),
    cancelWorkout: CancelScheduledWorkoutUseCase(schedule),
    startWorkout: StartScheduledWorkoutUseCase(schedule),
    getPublicWorkouts: GetPublicWorkoutsUseCase(templates),
    getPersonalWorkouts: GetPersonalWorkoutsUseCase(templates),
    programs: DemoPrograms(),
    initialDate: demoToday,
    now: () => demoToday,
  );
}

class DemoSchedule implements WorkoutScheduleRepository {
  DemoSchedule(this.items);
  final List<ScheduledWorkout> items;
  @override
  Future<List<ScheduledWorkout>> getRange(DateTime start, DateTime end) async =>
      items
          .where(
            (i) =>
                !i.scheduledDate.isBefore(start) &&
                !i.scheduledDate.isAfter(end),
          )
          .toList();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('La demo no inicia ni modifica entrenamientos.');
}

class DemoTemplates implements WorkoutRepository {
  @override
  Future<List<WorkoutTemplateSummary>> getPublicTemplates() async => [];
  @override
  Future<List<WorkoutTemplateSummary>> getPersonalTemplates() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('La demo no inicia ejecuciones.');
}

class DemoPrograms implements PreparationTrainingRepository {
  @override
  Future<List<AdaptiveProgramProgress>> refreshPrograms() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('La demo no activa programas.');
}

// Portal de filmación local; no inicializa el cliente de Supabase ni facturación.
import 'package:entrena_ui/conversation_view.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_agenda_page.dart';
import 'package:entrenaop_trainer/trainer_client_workspace.dart';
import 'package:entrenaop_trainer/trainer_client_workspace_repository.dart';
import 'package:entrenaop_trainer/trainer_clients_page.dart';
import 'package:entrenaop_trainer/trainer_shell.dart';
import 'package:entrenaop_trainer/trainer_workout_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/workout_template.dart';
import 'package:workout_core/running_step_codec.dart';

import '../../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import '../../../tools/promo/scenario.dart';
import '../../../tools/promo/portrait_data.dart';
import '../../../tools/promo/recipes.dart';

void main() => runApp(const TrainerDemo());

class TrainerDemo extends StatefulWidget {
  const TrainerDemo({super.key});
  @override
  State<TrainerDemo> createState() => TrainerDemoState();
}

class TrainerDemoState extends State<TrainerDemo> {
  final clients = DemoClients()
    ..current = TrainerAccess.fromJson({
      'trainer_id': 'demo-coach',
      'enabled': true,
      'effective': true,
      'client_limit': 10,
      'active_clients': 4,
      'revision': 1,
    })
    ..active = [
      for (final student in demoStudents)
        trainerRelation(
          student.name,
          personId: student.id,
          id: 'relation-${student.id}',
        ),
    ];
  final agenda = DemoAgenda();
  late final library = DemoLibrary(agenda);
  final workspace = DemoWorkspace();
  late final GoRouter router = GoRouter(
    initialLocation: '/agenda',
    routes: [
      ShellRoute(
        builder: (_, state, child) =>
            TrainerShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/clients',
            builder: (_, _) => TrainerClientsPage(
              repository: clients,
              photoLoader: loadDemoPhoto,
              onOpenClient: (id) => router.go('/clients/$id'),
            ),
          ),
          GoRoute(
            path: '/clients/:id',
            builder: (_, state) => TrainerClientWorkspacePage(
              repository: workspace,
              clientId: state.pathParameters['id']!,
              photoLoader: loadDemoPhoto,
            ),
          ),
          GoRoute(
            path: '/agenda',
            builder: (_, _) => TrainerAgendaPage(
              repository: agenda,
              now: demoToday,
              workouts: library,
              access: clients,
            ),
          ),
          GoRoute(
            path: '/messages',
            builder: (_, _) => ConversationView(
              header: () async =>
                  const ConversationHeader(title: 'Lucía Vega', canSend: true),
              load: (_) async => [
                ConversationEntry(
                  id: 'm1',
                  body: 'He terminado la sesión de hoy. Buenas sensaciones en la carrera.',
                  createdAt: demoToday.add(const Duration(hours: 10)),
                  mine: false,
                ),
                ConversationEntry(
                  id: 'm2',
                  body: '¡Buen trabajo, Lucía! He revisado tus registros. Tienes la próxima sesión en tu semana.',
                  createdAt: demoToday.add(
                    const Duration(hours: 10, minutes: 5),
                  ),
                  mine: true,
                ),
              ],
              send: (_, _) async {},
              newOperationId: () => 'demo-local',
              errorLabel: (_) => 'Demo local',
            ),
          ),
        ],
      ),
    ],
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: EntrenaTheme.dark,
    routerConfig: router,
  );
}

class DemoAgenda extends TrainerAgendaRepository {
  final additions = <TrainerAgendaItem>[];
  @override
  Future<List<TrainerAgendaItem>> range(
    DateTime from,
    DateTime to, {
    TrainerAgendaItem? after,
    TrainerAssignmentVisibility visibility =
        TrainerAssignmentVisibility.current,
  }) async {
    if (after != null) return [];
    return [
          for (var day = 0; day <= to.difference(from).inDays; day++)
            for (var person = 0; person < 4; person++)
              if (person == 0
                  ? [1, 3, 6, 7].contains(from.add(Duration(days: day)).weekday)
                  : (person + from.add(Duration(days: day)).weekday) % 2 == 0)
                TrainerAgendaItem.fromJson({
                  'id':
                      'demo-${agendaDate(from.add(Duration(days: day)))}-$person',
                  'template_id': demoRecipeFor(
                    from.add(Duration(days: day)),
                    person,
                  ).id,
                  'template_name': demoRecipeFor(
                    from.add(Duration(days: day)),
                    person,
                  ).name,
                  'template_version': demoRecipeFor(
                    from.add(Duration(days: day)),
                    person,
                  ).version,
                  'scheduled_date': agendaDate(from.add(Duration(days: day))),
                  'created_at': '2026-10-20T10:00:00Z',
                  'status': from.add(Duration(days: day)).isBefore(demoToday)
                      ? 'completed'
                      : 'planned',
                  'execution_id':
                      from.add(Duration(days: day)).isBefore(demoToday)
                      ? 'execution-$day-$person'
                      : null,
                  'note': 'Prioriza la técnica y registra las sensaciones al terminar.',
                  'client_id': demoStudents[person].id,
                  'client_name': demoStudents[person].name,
                }),
          ...additions,
        ]
        .where(
          (item) =>
              !item.assignment.date.isBefore(from) &&
              !item.assignment.date.isAfter(to),
        )
        .toList();
  }
}

WorkoutTemplate demoRecipeFor(DateTime date, int person) =>
    demoRecipes[person == 0
        ? switch (date.weekday) {
            1 => 0,
            3 => 1,
            6 => 2,
            _ => 3,
          }
        : (date.day + person) % 4];

Map<String, dynamic> demoClientRow(String id) {
  final student = demoStudents.firstWhere((s) => s.id == id);
  return {
    'person_id': id,
    'person_name': student.name,
    'profile_photo_path': id,
    'created_at': '2026-10-01T10:00:00Z',
    'updated_at': '2026-10-31T10:00:00Z',
    'accepted_at': '2026-10-01T10:00:00Z',
    'ended_at': null,
    'archived_at': null,
    'active_relation_id': 'relation-$id',
    'episode_count': 1,
  };
}

class DemoClients extends FakeTrainerRepository {
  @override
  Future<List<TrainerClient>> clients({
    TrainerClientState state = TrainerClientState.active,
    TrainerClient? before,
  }) async => state != TrainerClientState.active || before != null
      ? []
      : [
          for (final s in demoStudents)
            TrainerClient.fromJson(demoClientRow(s.id)),
        ];
}

class DemoLibrary extends TrainerWorkoutRepository {
  DemoLibrary(this.agenda);
  final DemoAgenda agenda;
  @override
  Future<List<TrainerWorkout>> workouts({
    TrainerWorkout? before,
    String query = '',
    bool? running,
    String? format,
  }) async => before != null
      ? []
      : [
          for (final recipe in demoRecipes)
            TrainerWorkout.fromJson({
              'id': recipe.id,
              'name': recipe.name,
              'version': recipe.version,
              'is_running': ['intervals', 'progressive'].contains(recipe.id),
              'formats': recipe.blocks.map((b) => b.format.name).toList(),
              'search_content': [recipe.name],
              'created_at': '2026-10-01T10:00:00Z',
            }),
        ];
  @override
  Future<WorkoutTemplate?> template(String id) async =>
      demoRecipes.firstWhere((r) => r.id == id);
  @override
  Future<void> assign({
    required String id,
    required String relationId,
    required String templateId,
    required DateTime date,
    String? note,
  }) async {
    final student = demoStudents.firstWhere(
      (s) => 'relation-${s.id}' == relationId,
    );
    final recipe = (await template(templateId))!;
    if (agenda.additions.any((item) => item.assignment.id == id)) return;
    agenda.additions.add(
      TrainerAgendaItem.fromJson({
        'id': id,
        'template_id': templateId,
        'template_name': recipe.name,
        'template_version': recipe.version,
        'scheduled_date': agendaDate(date),
        'created_at': demoToday.toIso8601String(),
        'status': 'planned',
        'note': note,
        'client_id': student.id,
        'client_name': student.name,
      }),
    );
  }

  @override
  Future<List<TrainerAssignment>> assignments(
    String clientId, {
    TrainerAssignment? before,
    TrainerAssignmentVisibility visibility = TrainerAssignmentVisibility.all,
  }) async => before != null
      ? []
      : (await agenda.range(DateTime(2026, 10, 1), DateTime(2026, 11, 1)))
            .where((i) => i.clientId == clientId)
            .map((i) => i.assignment)
            .toList();
  @override
  Future<WorkoutJson?> result(String assignmentId) async {
    final row = (await agenda.range(
      DateTime(2026, 10, 1),
      DateTime(2026, 11, 1),
    )).firstWhere((i) => i.assignment.id == assignmentId);
    final recipe = (await template(row.assignment.templateId))!;
    return {
      'id': 'execution-$assignmentId',
      'template_id': recipe.id,
      'template_name': recipe.name,
      'template_version': recipe.version,
      'status': 'completed',
      'started_at': row.assignment.date
          .add(const Duration(hours: 9))
          .toIso8601String(),
      'final_rpe': 7,
      'notes':
          'Buen control del ritmo y buenas sensaciones. Datos de demostración.',
      'workout_amrap_results': [],
      'workout_execution_sets': [
        for (var b = 0; b < recipe.blocks.length; b++)
          for (var i = 0; i < recipe.blocks[b].items.length; i++)
            for (final set in recipe.blocks[b].items[i].sets)
              {
                'id': '$assignmentId-$b-$i-${set.order}',
                'block_order': b,
                'item_order': i,
                'set_order': set.order,
                'block_name': recipe.blocks[b].name,
                'block_format':
                    recipe.blocks[b].format == WorkoutBlockFormat.running
                    ? 'running'
                    : recipe.blocks[b].format == WorkoutBlockFormat.warmUp
                    ? 'warm_up'
                    : recipe.blocks[b].format == WorkoutBlockFormat.coolDown
                    ? 'cool_down'
                    : 'straight_sets',
                'exercise_id': recipe.blocks[b].items[i].exerciseId,
                'exercise_name': recipe.blocks[b].items[i].exerciseName,
                'status': 'completed',
                'target_reps': set.targetReps,
                'target_duration_seconds': set.targetDurationSeconds,
                'target_distance_meters': set.targetDistanceMeters,
                'target_rir': set.targetRir,
                'target_pace_min_seconds_per_km': set.targetPaceMinSecondsPerKm,
                'target_pace_max_seconds_per_km': set.targetPaceMaxSecondsPerKm,
                'actual_reps': set.targetReps,
                'actual_duration_seconds':
                    set.targetDurationSeconds ??
                    (set.targetDistanceMeters == null
                        ? null
                        : (set.targetDistanceMeters! /
                                      1000 *
                                      ((set.targetPaceMinSecondsPerKm ?? 240) +
                                          5))
                                  .round() +
                              [-1, 0, 1, -2, 0, -1][set.order % 6]),
                'actual_distance_meters':
                    set.targetDistanceMeters ??
                    (set.targetDurationSeconds != null &&
                            set.targetPaceMinSecondsPerKm != null
                        ? set.targetDurationSeconds! *
                              1000 /
                              (set.targetPaceMinSecondsPerKm! + 5)
                        : null),
                'actual_rir': 2,
                'actual_rpe': 7,
                'result_source': 'manual',
                'rest_after_seconds': set.restAfterSeconds,
                'actual_recovery_duration_seconds': set.recoveryDurationSeconds,
                'running_step': set.runningStep == null
                    ? null
                    : RunningStepCodec.encode(set.runningStep!),
              },
      ],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Acción ajena al recorrido de grabación.');
}

class DemoWorkspace extends TrainerClientWorkspaceRepository {
  final notes = <String, (String, String, int)>{};
  @override
  Future<TrainerClientWorkspace> get(String clientId) async {
    final student = demoStudents.firstWhere((s) => s.id == clientId);
    final saved =
        notes[clientId] ??
        (
          'Priorizar la constancia y revisar sensaciones tras cada sesión.',
          student.goal,
          1,
        );
    return TrainerClientWorkspace.fromJson({
      'client': {
        'person_id': student.id,
        'profile_photo_path': student.id,
        'person_name': student.name,
        'created_at': '2026-10-01T10:00:00Z',
        'updated_at': '2026-10-30T10:00:00Z',
        'accepted_at': '2026-10-01T10:00:00Z',
        'ended_at': null,
        'archived_at': null,
        'active_relation_id': 'relation-$clientId',
        'episode_count': 1,
      },
      'relations': [
        {
          'id': 'relation-$clientId',
          'accepted_at': '2026-10-01T10:00:00Z',
          'ended_at': null,
        },
      ],
      'relations_complete': true,
      'notes': {'revision': saved.$3, 'notes': saved.$1, 'goal': saved.$2},
      'can_edit_notes': true,
    });
  }

  @override
  Future<int> saveNotes(
    String operationId,
    String clientId,
    int expectedRevision, {
    required String notes,
    required String goal,
  }) async {
    this.notes[clientId] = (notes, goal, expectedRevision + 1);
    return expectedRevision + 1;
  }

  @override
  Future<TrainerClientProgressReport> progress(
    String clientId,
    DateTime start,
    DateTime endExclusive,
  ) async => TrainerClientProgressReport(
    start: start,
    endExclusive: endExclusive,
    asOfDate: demoToday,
    amrap: const [],
    assignments: [
      for (var i = 0; i < 12; i++)
        {
          'id': 'assignment-$i',
          'scheduled_date': agendaDate(
            demoToday.subtract(Duration(days: i * 2)),
          ),
          'record_date': agendaDate(demoToday.subtract(Duration(days: i * 2))),
          'status': i == 0 ? 'planned' : 'completed',
          'execution_id': i == 0 ? null : 'execution-$i',
        },
    ],
    sets: [
      for (var i = 1; i < 12; i++)
        {
          'id': 'set-$i',
          'execution_id': 'execution-$i',
          'exercise_id': 'pull',
          'exercise_name': 'Dominadas',
          'record_date': agendaDate(demoToday.subtract(Duration(days: i * 2))),
          'status': 'completed',
          'block_format': 'straight_sets',
          'actual_reps': 6 + (12 - i) ~/ 4,
          'actual_load_kg': 0,
          'actual_rpe': 7,
          'actual_rir': 2,
        },
    ],
  );
}

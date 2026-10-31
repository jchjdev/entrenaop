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

import '../../../packages/trainer_access/test_support/fake_trainer_repository.dart';
import '../../../tools/promo/scenario.dart';

void main() => runApp(const TrainerDemo());

class TrainerDemo extends StatefulWidget {
  const TrainerDemo({super.key});
  @override
  State<TrainerDemo> createState() => TrainerDemoState();
}

class TrainerDemoState extends State<TrainerDemo> {
  final clients = FakeTrainerRepository()
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
  final workspace = DemoWorkspace();
  late final GoRouter router = GoRouter(
    initialLocation: '/clients',
    routes: [
      ShellRoute(
        builder: (_, state, child) =>
            TrainerShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/clients',
            builder: (_, _) => TrainerClientsPage(
              repository: clients,
              onOpenClient: (id) => router.go('/clients/$id'),
            ),
          ),
          GoRoute(
            path: '/clients/:id',
            builder: (_, state) => TrainerClientWorkspacePage(
              repository: workspace,
              clientId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/agenda',
            builder: (_, _) =>
                TrainerAgendaPage(repository: agenda, now: demoToday),
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
  @override
  Future<List<TrainerAgendaItem>> range(
    DateTime from,
    DateTime to, {
    TrainerAgendaItem? after,
    TrainerAssignmentVisibility visibility =
        TrainerAssignmentVisibility.current,
  }) async {
    if (after != null) return [];
    final week = demoToday.subtract(Duration(days: demoToday.weekday - 1));
    return [
          for (var day = 0; day < 7; day++)
            for (var person = 0; person < 4; person++)
              if ((person + day) % 2 == 0)
                TrainerAgendaItem.fromJson({
                  'id': 'session-$day-$person',
                  'template_id': 'template-$person',
                  'template_name': [
                    'Fuerza · Tren superior',
                    'Carrera · Ritmo cómodo',
                    'Fuerza y movilidad',
                    'Carrera · Cambios de ritmo',
                  ][person],
                  'template_version': 1,
                  'scheduled_date': agendaDate(week.add(Duration(days: day))),
                  'created_at': '2026-10-20T10:00:00Z',
                  'status': day < 4 ? 'completed' : 'planned',
                  'execution_id': day < 4 ? 'execution-$day-$person' : null,
                  'note': 'Sesión de demostración',
                  'client_id': demoStudents[person].id,
                  'client_name': demoStudents[person].name,
                }),
        ]
        .where(
          (item) =>
              !item.assignment.date.isBefore(from) &&
              item.assignment.date.isBefore(to),
        )
        .toList();
  }
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

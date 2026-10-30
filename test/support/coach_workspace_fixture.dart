import 'package:entrenaop/features/coach_workspace/domain/coach_planning_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:entrenaop/core/navigation/app_shell.dart';
import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';
import 'package:entrenaop/core/router/coach_workspace_routes.dart';
import 'package:entrenaop/features/coach_workspace/domain/coach_workspace_repository.dart';
import 'package:entrenaop/features/coach_workspace/presentation/coach_workspace_scope.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:trainer_access/trainer_calendar.dart';
import 'package:trainer_access/trainer_messages.dart';
import 'package:trainer_access/trainer_security.dart';
import 'package:workout_core/professional_opposition_goal.dart';
import 'package:workout_editor_ui/exercise_video_source.dart';

class FakeSecurity implements TrainerSecurity {
  bool verified = true;
  int checks = 0;
  @override
  Future<bool> assured() async {
    checks++;
    return verified;
  }

  @override
  Future<List<String>> factors() async => ['factor'];
  @override
  Future<void> verify(String factor, String code) async {
    verified = code == '123456';
  }

  @override
  Future<TrainerTotpSetup> enroll() async =>
      const TrainerTotpSetup('factor', '', 'clave');
}

class FakeCoach extends CoachWorkspaceRepository {
  bool enabled = true, failed = false, shareEnabled = true;
  int assignmentCalls = 0, failedReviews = 0;
  Map<String, dynamic>? resultData;
  List<Map<String, dynamic>> clips = [];
  final reviewCalls = <(String, String, int, String)>[];

  int clientCalls = 0, inboxCalls = 0;
  Future<List<TrainerClient>> Function()? readClients;
  Future<CoachAccount> Function()? readAccount;
  final clientRow = TrainerClient.fromJson({
    'person_id': 'isabel',
    'person_name': 'Isabel',
    'created_at': '2026-10-20T00:00:00Z',
    'updated_at': '2026-10-20T00:00:00Z',
    'accepted_at': '2026-10-20T00:00:00Z',
    'active_relation_id': 'relation',
    'episode_count': 1,
  });
  @override
  Future<CoachAccount> account() async {
    if (failed) throw StateError('Sin red');
    return readAccount == null
        ? CoachAccount(enabled: enabled)
        : readAccount!();
  }

  @override
  Future<TrainerMessageInbox> inbox() async {
    inboxCalls++;
    return const TrainerMessageInbox(
      totalUnread: 2,
      conversations: [],
      clients: {
        'isabel': TrainerClientMessageSummary(
          unreadCount: 2,
          relationId: 'relation',
        ),
      },
    );
  }

  @override
  Future<List<TrainerClient>> clients({
    TrainerClientState state = TrainerClientState.active,
    TrainerClient? before,
  }) async {
    clientCalls++;
    return readClients == null ? [clientRow] : readClients!();
  }

  @override
  Future<CoachClientDetail> client(String id) async => CoachClientDetail(
    clientRow,
    ProfessionalOppositionGoal(
      revision: 0,
      title: 'Policía',
      targets: const [],
      canEdit: true,
      historyComplete: true,
    ),
  );
  @override
  Future<List<CoachTechniquePending>> pendingTechnique({
    CoachTechniquePending? before,
  }) async => [];
  @override
  Future<List<CoachAssignment>> agenda(
    DateTime from,
    DateTime to, {
    CoachAssignment? after,
  }) async => [];
  @override
  Future<List<CoachAssignment>> reviews({CoachAssignment? before}) async => [];
  @override
  Future<List<CoachAssignment>> assignments(
    String id, {
    CoachAssignment? before,
  }) async => [];
  @override
  Future<SharedCalendarPage> sharedCalendar(
    String clientId,
    DateTime from,
    DateTime to, {
    SharedCalendarEntry? after,
  }) async => SharedCalendarPage.fromJson({
    'shared': shareEnabled,
    'has_more': false,
    'coaches': [],
    'items': !shareEnabled
        ? []
        : [
            {
              'id': 'foreign',
              'scheduled_date': '2026-10-28',
              'template_name': 'Series de Ervi',
              'source': 'coach',
              'status': 'planned',
              'is_own': false,
              'trainer_name': 'Ervi',
            },
            {
              'id': 'session',
              'scheduled_date': '2026-10-28',
              'template_name': 'Fuerza con Javier',
              'source': 'coach',
              'status': 'planned',
              'is_own': true,
              'trainer_name': 'Javier',
            },
          ],
  });
  @override
  Future<CoachAssignment> assignment(String id) async {
    assignmentCalls++;
    return CoachAssignment(
      id: id,
      name: 'Fuerza con Javier',
      date: DateTime(2026, 10, 28),
      createdAt: DateTime(2026, 10, 28),
      clientId: 'isabel',
      clientName: 'Isabel',
      status: 'completed',
    );
  }

  @override
  Future<Map<String, dynamic>?> result(String id) async => resultData;
  @override
  Future<void> review(
    String operation,
    String assignmentId,
    int revision,
    String note,
  ) async {
    reviewCalls.add((operation, assignmentId, revision, note));
    if (failedReviews-- > 0) throw StateError('Sin confirmar');
  }

  @override
  Future<List<Map<String, dynamic>>> technique(String assignmentId) async =>
      clips;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMessages implements TrainerInboxMessageRepository {
  int loads = 0, reads = 0;
  @override
  Future<TrainerConversationContext> context(String id) async =>
      TrainerConversationContext.fromJson({'name': 'Isabel', 'can_send': true});
  @override
  Future<List<TrainerMessage>> list(
    String id, {
    DateTime? beforeAt,
    String? beforeId,
  }) async {
    loads++;
    return [
      TrainerMessage.fromJson({
        'id': 'm1',
        'body': 'Hola, entrenador',
        'sender_id': 'isabel',
        'created_at': '2026-10-28T09:00:00Z',
      }, 'javier'),
    ];
  }

  @override
  Future<void> markRead(List<String> ids) async {
    reads++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeVideo implements ExerciseVideoSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GoRouter createRouter(
  FakeCoach repo,
  FakeSecurity security, {
  FakeMessages? messages,
  CoachPlanningRepository? planning,
  String initial = '/home',
}) {
  final exits = WorkflowExitRegistry();
  return GoRouter(
    initialLocation: initial,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => CoachWorkspaceEntry(
          key: const ValueKey('javier'),
          repository: repo,
          planning: planning,
          security: security,
          messages: messages ?? FakeMessages(),
          video: FakeVideo(),
          child: AppShell(navigationShell: shell),
        ),
        branches: [
          for (final path in [
            '/home',
            '/plan',
            '/library',
            '/evolution',
            '/my-trainer',
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (_, _) => Scaffold(
                    appBar: AppBar(title: Text('Página $path')),
                    body: Text(
                      path == '/my-trainer'
                          ? 'Mi preparador es Ervi'
                          : 'Contenido $path',
                    ),
                  ),
                  routes: [
                    GoRoute(
                      path: 'detail',
                      builder: (_, _) =>
                          const Scaffold(body: Text('Mi detalle personal')),
                    ),
                  ],
                ),
              ],
            ),
          coachWorkspaceBranch(exits),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('Perfil personal')),
      ),
    ],
  );
}

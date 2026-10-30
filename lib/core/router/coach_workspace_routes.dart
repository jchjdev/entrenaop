import '../../features/coach_workspace/presentation/coach_exercise_library.dart';
import '../../features/coach_workspace/presentation/coach_planning_pages.dart';
import '../../features/coach_workspace/presentation/coach_followup_actions.dart';
import '../../features/coach_workspace/presentation/coach_assignment_actions.dart';
import '../../features/coach_workspace/presentation/coach_workspace_scope.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/workflow_exit_guard.dart';
import '../../features/coach_workspace/presentation/coach_security_gate.dart';
import '../../features/coach_workspace/presentation/coach_shell.dart';
import '../../features/coach_workspace/presentation/coach_pages.dart';
import '../../features/coach_workspace/presentation/coach_detail_pages.dart';
import 'material_app_route.dart';

StatefulShellBranch coachWorkspaceBranch(WorkflowExitRegistry exits) {
  GoRoute conversation(String path) => materialAppRoute(
    path: path,
    onExit: (_, state) => exits.requestExit(state.pageKey),
    builder: (_, state) => WorkflowExitScope(
      controller: exits.controller(state.pageKey),
      child: CoachConversationPage(
        key: ValueKey(state.pathParameters['relationId']),
        relationId: state.pathParameters['relationId']!,
      ),
    ),
  );
  GoRoute planning(String path, Widget Function(GoRouterState) page) =>
      materialAppRoute(
        path: path,
        onExit: (_, state) => exits.requestExit(state.pageKey),
        builder: (context, state) => WorkflowExitScope(
          controller: exits.controller(state.pageKey),
          child: CoachWorkspaceScope.of(context).planning == null
              ? const Scaffold(
                  body: Center(
                    child: Text(
                      'No se ha podido abrir la planificación. Vuelve al resumen e inténtalo de nuevo.',
                    ),
                  ),
                )
              : page(state),
        ),
      );
  DateTime? day(GoRouterState state) {
    final raw = state.uri.queryParameters['day'],
        d = DateTime.tryParse(state.uri.queryParameters['day'] ?? '');
    return d != null &&
            d.year >= 2000 &&
            d.year <= 2200 &&
            raw ==
                '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
        ? d
        : null;
  }

  return StatefulShellBranch(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) =>
            CoachSecurityGate(child: CoachShell(navigationShell: shell)),
        branches: [
          StatefulShellBranch(
            routes: [
              materialAppRoute(
                path: '/coach',
                builder: (_, _) => const CoachSummaryPage(),
                routes: [
                  planning(
                    'exercises',
                    (_) => const CoachExerciseLibraryPage(),
                  ),
                  planning(
                    'library',
                    (state) => CoachLibraryPage(
                      pick: state.uri.queryParameters['pick'] == '1',
                    ),
                  ),
                  planning(
                    'library/:sessionId',
                    (state) => CoachSessionPreviewPage(
                      id: state.pathParameters['sessionId']!,
                      pick: state.uri.queryParameters['pick'] == '1',
                    ),
                  ),
                  planning(
                    'choose-client',
                    (_) => const CoachClientPickerPage(),
                  ),
                  planning(
                    'assign',
                    (state) => CoachAssignPage(
                      key: ValueKey(state.uri.toString()),
                      clientId: state.uri.queryParameters['client'],
                      sessionId: state.uri.queryParameters['session'],
                      day: day(state),
                    ),
                  ),
                  planning(
                    'notes/:clientId',
                    (state) => CoachNotesPage(
                      clientId: state.pathParameters['clientId']!,
                    ),
                  ),
                  planning(
                    'form/:id',
                    (state) =>
                        CoachFormResponsePage(id: state.pathParameters['id']!),
                  ),
                  planning(
                    'forms/:clientId',
                    (state) => CoachFormsPage(
                      clientId: state.pathParameters['clientId']!,
                    ),
                  ),
                  planning(
                    'send-form',
                    (state) => CoachSendFormPage(
                      clientId: state.uri.queryParameters['client'] ?? '',
                    ),
                  ),
                  planning(
                    'new-appointment',
                    (state) => CoachAppointmentPage(
                      clientId: state.uri.queryParameters['client'],
                      day: day(state),
                    ),
                  ),
                  planning(
                    'appointment/:id',
                    (state) => CoachAppointmentPage(
                      key: ValueKey(state.pathParameters['id']),
                      id: state.pathParameters['id']!,
                    ),
                  ),
                  planning(
                    'move/:id',
                    (state) => CoachScheduleActionPage(
                      id: state.pathParameters['id']!,
                    ),
                  ),
                  planning(
                    'withdraw/:id',
                    (state) => CoachScheduleActionPage(
                      id: state.pathParameters['id']!,
                      withdraw: true,
                    ),
                  ),
                  materialAppRoute(
                    path: 'client-history/:clientId',
                    builder: (_, state) => CoachClientHistoryPage(
                      key: ValueKey(state.pathParameters['clientId']),
                      clientId: state.pathParameters['clientId']!,
                    ),
                  ),
                  materialAppRoute(
                    path: 'videos',
                    builder: (_, _) => const CoachPendingTechniquePage(),
                  ),
                  materialAppRoute(
                    path: 'calendar/:clientId',
                    builder: (_, state) => CoachSharedCalendarPage(
                      key: ValueKey(state.pathParameters['clientId']),
                      clientId: state.pathParameters['clientId']!,
                    ),
                  ),
                  materialAppRoute(
                    path: 'reviews',
                    builder: (_, _) => const CoachReviewsPage(),
                  ),
                  materialAppRoute(
                    path: 'assignment/:assignmentId',
                    builder: (_, state) => CoachAssignmentPage(
                      key: ValueKey(state.pathParameters['assignmentId']),
                      assignmentId: state.pathParameters['assignmentId']!,
                    ),
                  ),
                  materialAppRoute(
                    path: 'technique/:assignmentId',
                    builder: (_, state) => CoachTechniquePage(
                      key: ValueKey(state.pathParameters['assignmentId']),
                      assignmentId: state.pathParameters['assignmentId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              materialAppRoute(
                path: '/coach/agenda',
                builder: (_, _) => const CoachAgendaPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              materialAppRoute(
                path: '/coach/clients',
                builder: (_, _) => const CoachClientsPage(),
                routes: [
                  materialAppRoute(
                    path: ':clientId',
                    builder: (_, state) => CoachClientPage(
                      key: ValueKey(state.pathParameters['clientId']),
                      clientId: state.pathParameters['clientId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              materialAppRoute(
                path: '/coach/messages',
                builder: (_, _) => const CoachClientsPage(messages: true),
                routes: [conversation(':relationId')],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

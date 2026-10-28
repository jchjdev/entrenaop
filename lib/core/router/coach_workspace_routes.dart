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

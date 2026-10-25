import 'package:entrena_ui/entrena_ui.dart';
import 'package:entrenaop_trainer/trainer_client_forms_route.dart';
import 'package:entrenaop_trainer/trainer_client_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trainer_access/trainer_followup_codec.dart';

import 'trainer_form_flow_test.dart' show FormFixture, sample;
import 'trainer_client_workspace_test.dart' show WorkspaceFixture;

class AnsweredForms extends FormFixture {
  @override
  Future<List<TrainerFormAssignment>> assignments(
    String clientId, {
    TrainerFormAssignment? before,
  }) async => [
    TrainerFormAssignment.fromJson({
      'id': 'assignment',
      'client_id': clientId,
      'relation_id': 'relation',
      'form_id': 'version-1',
      'family_id': 'family',
      'version': 1,
      'content': TrainerFollowupCodec.encode(sample()),
      'due_date': '2026-10-21',
      'created_at': '2026-10-20T12:00:00Z',
      'submitted_at': '2026-10-21T12:00:00Z',
      'can_respond': false,
      'answers': {'stable-question': 'Todo bien'},
    }),
  ];
}

void main() {
  testWidgets(
    'cerrar respuestas del alumno cierra el diálogo raíz y conserva la ficha anidada',
    (t) async {
      final router = GoRouter(
        initialLocation: '/clients/client/forms',
        routes: [
          ShellRoute(
            builder: (_, state, child) =>
                TrainerClientNavigation.wrap(state.uri, child),
            routes: [
              GoRoute(
                path: '/clients/client/forms',
                builder: (_, _) => TrainerClientContentRoute(
                  workspace: WorkspaceFixture(),
                  forms: AnsweredForms(),
                  clientId: 'client',
                ),
              ),
              GoRoute(
                path: '/clients/client/workouts',
                builder: (_, _) =>
                    const Scaffold(body: Text('Calendario del alumno')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(
        MaterialApp.router(theme: EntrenaTheme.dark, routerConfig: router),
      );
      await t.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await t.tap(find.text('Revisión privada'));
        await t.pumpAndSettle();
        expect(find.text('Comentario\nTodo bien'), findsOneWidget);
        await t.tap(find.text('Cerrar'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Formularios · Alumno'), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.path,
          '/clients/client/forms',
        );
      }
      await t.tap(find.text('Planificación'));
      await t.pumpAndSettle();
      expect(find.text('Calendario del alumno'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:entrenaop_trainer/trainer_client_planning_repository.dart';
import 'package:entrenaop_trainer/trainer_client_goals_repository.dart';

import 'trainer_program_work_repository_test.dart' show ProgramWorkServer;
import 'trainer_exercise_repository_test.dart' show owner;

void main() {
  test('fija cuenta, alumno y cursor civil sin recorrer la cartera', () async {
    final server = ProgramWorkServer();
    addTearDown(server.client.dispose);
    await server.login();
    server.respond = (request, name, params) async {
      expect(name, 'list_trainer_client_agenda');
      expect(params['p_expected_owner'], owner);
      expect(params['p_client_id'], 'student');
      expect(params['p_from'], '2026-10-26');
      expect(params['p_to'], '2026-11-01');
      return server.json(request, {
        'items': [
          {
            'id': 'scheduled',
            'template_id': 'template',
            'template_name': 'Fuerza',
            'template_version': 2,
            'scheduled_date': '2026-10-28',
            'created_at': '2026-10-25T10:00:00Z',
            'status': 'planned',
            'planning_revision': 4,
            'result_revision': 3,
            'is_running': false,
          },
        ],
        'has_more': true,
      });
    };
    final repo = SupabaseTrainerClientPlanningRepository(server.client, owner);
    final page = await repo.week(
      'student',
      DateTime(2026, 10, 26),
      DateTime(2026, 11, 1),
    );
    expect(page.items.single.assignment.revision, 4);
    expect(page.hasMore, true);
    await repo.week(
      'student',
      DateTime(2026, 10, 26),
      DateTime(2026, 11, 1),
      after: page.items.single,
    );
    expect(server.calls.last.params['p_after_date'], '2026-10-28');
    expect(server.calls.last.params['p_after_id'], 'scheduled');
    expect(
      SupabaseTrainerClientGoalsRepository(server.client, owner).scope,
      SupabaseTrainerClientGoalsRepository(server.client, owner).scope,
    );
  });
  test('rechaza credenciales cambiadas durante el transporte', () async {
    final server = ProgramWorkServer();
    addTearDown(server.client.dispose);
    await server.login();
    server.replaceTransportIdentity = true;
    server.respond = (_, _, _) async => throw StateError('No debe consultar');
    await expectLater(
      SupabaseTrainerClientPlanningRepository(
        server.client,
        owner,
      ).week('student', DateTime(2026, 10, 26), DateTime(2026, 11, 1)),
      throwsA(isA<PostgrestException>()),
    );
  });
}

import 'package:entrenaop/features/coach_workspace/data/supabase_coach_planning_repository.dart';
import 'package:entrenaop/features/coach_workspace/domain/coach_planning_repository.dart';
import 'package:entrenaop/features/coach_workspace/domain/coach_workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coach_workspace_repository_test.dart' show CoachServer, owner;

void main() {
  test('la consulta de coincidencias conserva la fecha civil y la proyección privada del servidor', () async {
    final api = CoachServer();
    addTearDown(api.client.dispose);
    await api.login();
    api.responses['preview_trainer_schedule'] = [
      {'date': '2026-11-03', 'has_other_workout': true},
    ];
    final r = await SupabaseCoachPlanningRepository(
      api.client,
      owner,
    ).schedule('alumno', DateTime(2026, 11, 3));
    expect(r.single['has_other_workout'], true);
    expect(api.payload, {
      'p_client_id': 'alumno',
      'p_from': '2026-11-03',
      'p_to': '2026-11-03',
    });
  });
  test(
    'el reintento de asignación conserva ID, destinatario, versión y nota',
    () async {
      final api = CoachServer();
      addTearDown(api.client.dispose);
      await api.login();
      api.responses['assign_trainer_workout'] = 'assignment';
      final repo = SupabaseCoachPlanningRepository(api.client, owner);
      Future<void> send() => repo.assign(
        operationId: 'operation',
        relationId: 'relation',
        templateId: 'version',
        date: DateTime(2026, 11, 3),
        note: '  Nota  ',
      );
      await send();
      final first = Map<String, dynamic>.from(api.payload);
      await send();
      expect(api.payload, first);
      expect(first, {
        'p_id': 'operation',
        'p_relation_id': 'relation',
        'p_template_id': 'version',
        'p_date': '2026-11-03',
        'p_note': 'Nota',
      });
      await expectLater(
        repo.assign(
          operationId: 'other',
          relationId: 'relation',
          templateId: 'version',
          date: DateTime(2026),
          note: 'x' * 501,
        ),
        throwsFormatException,
      );
    },
  );
  test('mover conserva revisión y nota sin enviar una nueva receta', () async {
    final api = CoachServer();
    addTearDown(api.client.dispose);
    await api.login();
    api.responses['change_trainer_assignment'] = {};
    final repo = SupabaseCoachPlanningRepository(api.client, owner);
    await repo.move(
      'operation',
      CoachAssignment(
        id: 'assignment',
        name: 'Sesión',
        date: DateTime(2026, 11, 1),
        clientId: 'client',
        clientName: 'Alumno',
        status: 'planned',
        createdAt: DateTime(2026),
        planningRevision: 7,
        note: 'Nota original',
      ),
      DateTime(2026, 11, 3),
    );
    expect(api.payload['p_expected_revision'], 7);
    expect(api.payload['p_note'], 'Nota original');
    expect(api.payload['p_recipe'], null);
    expect(api.payload['p_date'], '2026-11-03');
  });
  test(
    'notas sin permiso no escriben y las autorizadas respetan su revisión',
    () async {
      final api = CoachServer();
      addTearDown(api.client.dispose);
      await api.login();
      api.responses['save_trainer_client_notes'] = 8;
      final repo = SupabaseCoachPlanningRepository(api.client, owner);
      await expectLater(
        repo.saveNotes(
          'op',
          'client',
          const CoachPrivateNotes(
            notes: '',
            goal: '',
            revision: 7,
            canEdit: false,
          ),
          'texto',
          'meta',
        ),
        throwsFormatException,
      );
      expect(
        api.requests.where(
          (r) => r.url.path.endsWith('save_trainer_client_notes'),
        ),
        isEmpty,
      );
      await repo.saveNotes(
        'op',
        'client',
        const CoachPrivateNotes(
          notes: '',
          goal: '',
          revision: 7,
          canEdit: true,
        ),
        ' texto ',
        ' meta ',
      );
      expect(api.payload['p_expected_revision'], 7);
      expect(api.payload['p_notes'], 'texto');
      expect(api.payload['p_goal'], 'meta');
    },
  );
  test('el acceso inactivo impide consultar la receta privada aunque exista sesión', () async {
    final api = CoachServer();
    addTearDown(api.client.dispose);
    await api.login();
    api.responses['get_my_trainer_account_status'] = {'enabled': false};
    await expectLater(
      SupabaseCoachPlanningRepository(api.client, owner).template('template'),
      throwsStateError,
    );
    expect(
      api.requests.where((r) => r.url.path.endsWith('workout_templates')),
      isEmpty,
    );
  });
  test('la receta se restringe al propietario y origen profesional antes de decodificar', () async {
    final api = CoachServer();
    addTearDown(api.client.dispose);
    await api.login();
    api.responses['get_my_trainer_account_status'] = {'enabled': true};
    api.responses['workout_templates'] = {
      'id': 'template',
      'name': 'Sesión',
      'version': 2,
      'description': null,
      'estimated_duration_minutes': 45,
      'workout_blocks': [],
    };
    final result = await SupabaseCoachPlanningRepository(
      api.client,
      owner,
    ).template('template');
    expect(result.version, 2);
    final query = api.requests.last.url.queryParameters;
    expect(query['owner_user_id'], 'eq.$owner');
    expect(query['origin'], 'eq.coach');
  });
  test('la biblioteca usa cursor compuesto sin descargar recetas ni datos de alumnos', () async {
    final api = CoachServer();
    addTearDown(api.client.dispose);
    await api.login();
    api.responses['list_trainer_workouts'] = [];
    await SupabaseCoachPlanningRepository(api.client, owner).sessions(
      before: CoachLibrarySession(
        id: 'cursor',
        name: 'Sesión',
        version: 2,
        isRunning: false,
        createdAt: DateTime.utc(2026, 11, 1, 10),
      ),
    );
    expect(api.payload, {
      'p_before_at': '2026-11-01T10:00:00.000Z',
      'p_before_id': 'cursor',
    });
  });
}

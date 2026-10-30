import 'package:entrenaop/features/coach_workspace/domain/coach_workspace_repository.dart';
import 'package:trainer_access/trainer_access.dart';
import 'package:workout_core/professional_assessment.dart';
import 'package:workout_core/professional_opposition_goal.dart';

import 'coach_workspace_fixture.dart';

/// Datos de revisión de interfaz. No conecta cuentas ni modifica el servidor.
class CoachMobileFixture extends FakeCoach {
  @override
  Future<CoachClientDetail> client(String id) async => CoachClientDetail(
    clientRow,
    ProfessionalOppositionGoal(
      revision: 1,
      title: 'Policía · preparación de pruebas físicas',
      targetDate: DateTime(2027, 3, 15),
      targets: const [
        ProfessionalOppositionGoalTarget(
          protocol: ProfessionalAssessmentTest(
            id: 'carrera',
            name: 'Carrera de 1.000 metros',
            unit: ProfessionalMarkUnit.seconds,
            direction: ProfessionalBetterDirection.lower,
            resolution: 0.01,
            instructions: 'Completa la distancia medida.',
            maximumAttempts: 1,
            retryPolicy: ProfessionalRetryPolicy.none,
          ),
          value: 240,
          latest: 255,
          hasLatestEvidence: true,
        ),
        ProfessionalOppositionGoalTarget(
          protocol: ProfessionalAssessmentTest(
            id: 'dominadas',
            name: 'Dominadas estrictas en suspensión',
            unit: ProfessionalMarkUnit.repetitions,
            direction: ProfessionalBetterDirection.higher,
            resolution: 1,
            instructions: 'Extiende los brazos entre repeticiones.',
            maximumAttempts: 1,
            retryPolicy: ProfessionalRetryPolicy.none,
          ),
          value: 10,
          latest: 8,
          hasLatestEvidence: true,
        ),
      ],
    ),
  );
  @override
  TrainerClient get clientRow => TrainerClient.fromJson({
    'person_id': 'isabel',
    'person_name': 'Isabel Rodríguez Fernández',
    'created_at': '2026-10-20T00:00:00Z',
    'updated_at': '2026-10-20T00:00:00Z',
    'accepted_at': '2026-10-20T00:00:00Z',
    'active_relation_id': 'relation',
    'episode_count': 1,
  });

  CoachAssignment sample(String id, {bool completed = false}) =>
      CoachAssignment(
        id: id,
        name: completed
            ? 'Fuerza de piernas y estabilidad para las pruebas físicas'
            : 'Series de 400 m y técnica de carrera',
        date: DateTime.now(),
        createdAt: DateTime.now(),
        clientId: 'isabel',
        clientName: clientRow.name,
        status: completed ? 'completed' : 'planned',
        relationId: 'relation',
      );

  @override
  Future<List<CoachAssignment>> agenda(
    DateTime from,
    DateTime to, {
    CoachAssignment? after,
  }) async => after == null ? [sample('carrera')] : [];

  @override
  Future<List<CoachAssignment>> reviews({CoachAssignment? before}) async =>
      before == null ? [sample('session', completed: true)] : [];

  @override
  Future<List<CoachAssignment>> assignments(
    String id, {
    CoachAssignment? before,
  }) async => before == null
      ? [sample('carrera'), sample('session', completed: true)]
      : [];

  @override
  Future<CoachAssignment> assignment(String id) async =>
      sample(id, completed: id == 'session');

  @override
  Future<Map<String, dynamic>?> result(String assignmentId) async =>
      assignmentId != 'session'
      ? null
      : {
          'id': 'execution',
          'template_id': 'template',
          'template_name': sample('session', completed: true).name,
          'template_version': 2,
          'status': 'completed',
          'started_at': '2026-10-30T10:00:00Z',
          'result_revision': 1,
          'notes': 'Buenas sensaciones. He bajado un poco la carga en las últimas series para mantener la técnica.',
          'workout_execution_sets': [],
        };

  @override
  Future<List<CoachTechniquePending>> pendingTechnique({
    CoachTechniquePending? before,
  }) async => before == null
      ? [
          CoachTechniquePending(
            id: 'clip',
            assignmentId: 'session',
            createdAt: DateTime.now(),
            clientName: clientRow.name,
            name: 'Dominada prona · revisión de técnica',
          ),
        ]
      : [];

  @override
  Future<List<Map<String, dynamic>>> technique(String assignmentId) async => [
    {
      'id': 'clip',
      'created_at': '2026-10-30T10:00:00Z',
      'status': 'processing',
      'can_feedback': false,
      'feedback': [
        {'second': 12, 'body': 'Mantén el tronco estable durante la subida.'},
      ],
    },
  ];
}

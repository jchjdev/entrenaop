import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:workout_core/professional_assessment.dart';
import 'package:workout_core/professional_assessment_codec.dart';
import 'package:workout_core/professional_opposition_goal.dart';

abstract class TrainerClientGoalsRepository {
  /// Un adaptador reconstruido para la misma cuenta no invalida un envío incierto.
  Object get scope => this;
  Future<ProfessionalOppositionGoal> get(String clientId);
  Future<List<ProfessionalAssessmentTest>> protocols();
  Future<int> save(
    String operationId,
    String clientId,
    int expectedRevision,
    ProfessionalOppositionGoalDraft draft,
  );
}

class SupabaseTrainerClientGoalsRepository
    implements TrainerClientGoalsRepository {
  const SupabaseTrainerClientGoalsRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  @override
  Object get scope => (client, userId);

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
    final result = await authenticatedTrainerRpc(
      client,
      userId,
      name,
      params: {...params, 'p_expected_owner': userId},
    );
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
    return result;
  }

  @override
  Future<ProfessionalOppositionGoal> get(String clientId) async =>
      ProfessionalOppositionGoal.fromJson(
        Map<String, dynamic>.from(
          await _rpc('get_trainer_client_goal', {'p_client_id': clientId})
              as Map,
        ),
      );

  @override
  Future<List<ProfessionalAssessmentTest>> protocols() async =>
      (await _rpc('list_trainer_goal_protocols', {}) as List)
          .map(
            (row) => ProfessionalAssessmentCodec.test(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();

  @override
  Future<int> save(
    String operationId,
    String clientId,
    int expectedRevision,
    ProfessionalOppositionGoalDraft draft,
  ) async => (await _rpc('save_trainer_client_goal', {
    'p_operation_id': operationId,
    'p_client_id': clientId,
    'p_expected_revision': expectedRevision,
    'p_payload': draft.toJson(),
  }) as num).toInt();
}

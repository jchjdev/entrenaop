import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:workout_core/professional_assessment.dart';
import 'package:workout_core/professional_assessment_codec.dart';

abstract class TrainerAssessmentRepository {
  Future<List<ProfessionalAssessmentVersion>> list();
  Future<ProfessionalAssessmentVersion> get(String id);
  Future<List<ProfessionalAssessmentTest>> catalog();
  Future<String> save(
    String operationId,
    ProfessionalAssessmentVersion form, {
    String? previousId,
    int expectedRevision = 0,
  });
  Future<void> assign(
    String operationId,
    String relationId,
    String assessmentId,
    DateTime date,
  );
  Future<List<ProfessionalAssessmentDelivery>> deliveries(
    String clientId, {
    ProfessionalAssessmentDelivery? before,
  });
  Future<ProfessionalAssessmentDelivery> delivery(String id);
}

class SupabaseTrainerAssessmentRepository
    implements
        TrainerAssessmentRepository,
        ProfessionalAssessmentEventRepository {
  const SupabaseTrainerAssessmentRepository(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  Future<dynamic> _rpc(String name, [Map<String, dynamic>? params]) async {
    void identity() {
      if (client.auth.currentUser?.id != userId) {
        throw StateError('La cuenta ha cambiado.');
      }
    }

    identity();
    final result = await authenticatedTrainerRpc(
      client,
      userId,
      name,
      params: params,
    );
    identity();
    return result;
  }

  @override
  Future<List<ProfessionalAssessmentEvent>> listAssessmentEvents({
    required DateTime start,
    required DateTime endExclusive,
    ProfessionalAssessmentEvent? before,
  }) async {
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final rows = await _rpc('list_trainer_assessment_events', {
      'p_start': day(start),
      'p_end_exclusive': day(endExclusive),
      'p_as_trainer': true,
      ...?before?.cursorParameters,
    }) as List;
    return rows
        .map(
          (r) => ProfessionalAssessmentCodec.event(
            Map<String, dynamic>.from(r as Map),
          ),
        )
        .toList();
  }

  @override
  Future<List<ProfessionalAssessmentVersion>> list() async =>
      (await _rpc('list_trainer_assessments') as List)
          .map(
            (r) => ProfessionalAssessmentCodec.decode(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
  @override
  Future<ProfessionalAssessmentVersion> get(String id) async =>
      ProfessionalAssessmentCodec.decode(
        Map<String, dynamic>.from(
          await _rpc('get_trainer_assessment', {'p_id': id}) as Map,
        ),
      );
  @override
  Future<List<ProfessionalAssessmentTest>> catalog() async =>
      (await _rpc('list_trainer_assessment_catalog') as List)
          .map(
            (r) => ProfessionalAssessmentCodec.test(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
  @override
  Future<String> save(
    String operationId,
    ProfessionalAssessmentVersion form, {
    String? previousId,
    int expectedRevision = 0,
  }) async => await _rpc('save_trainer_assessment', {
    'p_operation_id': operationId,
    'p_payload': ProfessionalAssessmentCodec.encode(form),
    'p_previous_id': previousId,
    'p_expected_revision': expectedRevision,
  }) as String;
  @override
  Future<void> assign(
    String operationId,
    String relationId,
    String assessmentId,
    DateTime date,
  ) async {
    await _rpc('assign_trainer_assessment', {
      'p_operation_id': operationId,
      'p_relation_id': relationId,
      'p_assessment_id': assessmentId,
      'p_date':
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    });
  }

  @override
  Future<List<ProfessionalAssessmentDelivery>> deliveries(
    String clientId, {
    ProfessionalAssessmentDelivery? before,
  }) async =>
      (await _rpc('list_trainer_assessment_deliveries', {
            'p_client_id': clientId,
            'p_before_at': before?.createdAt.toUtc().toIso8601String(),
            'p_before_id': before?.id,
          }) as List)
          .map(
            (r) => ProfessionalAssessmentCodec.delivery(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
  @override
  Future<ProfessionalAssessmentDelivery> delivery(String id) async =>
      ProfessionalAssessmentCodec.delivery(
        Map<String, dynamic>.from(
          await _rpc('get_trainer_assessment_delivery', {'p_id': id}) as Map,
        ),
      );
}

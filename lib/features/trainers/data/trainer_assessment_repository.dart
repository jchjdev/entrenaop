import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/professional_assessment.dart';
import 'package:workout_core/professional_assessment_codec.dart';

class SupabaseProfessionalAssessmentStudentRepository
    implements
        ProfessionalAssessmentStudentRepository,
        ProfessionalAssessmentEventRepository {
  const SupabaseProfessionalAssessmentStudentRepository(
    this.client,
    this.userId,
  );
  final SupabaseClient client;
  final String userId;
  Future<dynamic> _rpc(String name, Map<String, dynamic> parameters) async {
    void identity() {
      if (client.auth.currentUser?.id != userId) {
        throw StateError('La cuenta ha cambiado.');
      }
    }

    identity();
    final result = await client.rpc(name, params: parameters);
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
      'p_as_trainer': false,
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
  Future<List<ProfessionalAssessmentDelivery>> mine({
    ProfessionalAssessmentDelivery? before,
  }) async =>
      (await _rpc('list_trainer_assessment_deliveries', {
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
  @override
  Future<ProfessionalAssessmentDelivery> start(
    String operationId,
    ProfessionalAssessmentDelivery delivery,
  ) async {
    await _rpc('write_trainer_assessment', {
      'p_operation_id': operationId,
      'p_id': delivery.id,
      'p_expected_revision': delivery.revision,
      'p_action': 'start',
      'p_payload': {'protocols_confirmed': true},
    });
    return this.delivery(delivery.id);
  }

  @override
  Future<ProfessionalAssessmentDelivery> save(
    String operationId,
    ProfessionalAssessmentDelivery delivery,
    Map<String, List<ProfessionalAssessmentAttempt>> answers, {
    required bool finish,
  }) async {
    final normalized = ProfessionalAssessmentValidator.answers(
      delivery.battery,
      answers,
      complete: finish,
    );
    await _rpc('write_trainer_assessment', {
      'p_operation_id': operationId,
      'p_id': delivery.id,
      'p_expected_revision': delivery.revision,
      'p_action': finish ? 'finish' : 'save',
      'p_payload': ProfessionalAssessmentCodec.encodeAnswers(normalized),
    });
    return this.delivery(delivery.id);
  }
}

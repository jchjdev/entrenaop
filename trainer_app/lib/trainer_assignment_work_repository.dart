import 'package:trainer_access/authenticated_rpc.dart';
import 'package:workout_editor_ui/editor_work_checkpoint.dart';
import 'package:workout_editor_ui/workout_editor_work.dart';

import 'trainer_workout_work_repository.dart';

/// Guarda con el mismo checkpoint. Solo la finalización aplica la receta y
/// exige confirmar la previsualización del servidor ligada a esa intención.
class SupabaseTrainerAssignmentWorkRepository
    extends SupabaseTrainerWorkoutWorkRepository {
  const SupabaseTrainerAssignmentWorkRepository(
    super.client,
    super.userId, {
    required this.review,
  });
  final Future<void> Function(bool hasCoincidence) review;

  @override
  Future<String> finalize(WorkoutEditorWork work) async {
    if (work.origin['assignmentId'] == null) {
      throw const FormatException('El trabajo no pertenece a una pauta.');
    }
    final current = await load(work.id);
    if (current == null ||
        canonicalEditorState(current.origin) !=
            canonicalEditorState(work.origin)) {
      throw const WorkoutWorkConflict();
    }
    if (current.resultId case final result?) return result;
    if (current.revision != work.revision) {
      throw const WorkoutWorkConflict();
    }
    final parameters = {
      'p_expected_owner': userId,
      'p_id': work.id,
      'p_revision': work.revision,
    };
    final preview = Map<String, dynamic>.from(
      await authenticatedTrainerRpc(
        client,
        userId,
        'preview_trainer_assignment_session_work',
        params: parameters,
      ) as Map,
    );
    await review(preview['has_date_coincidence'] == true);
    try {
      return await authenticatedTrainerRpc(
        client,
        userId,
        'finalize_trainer_assignment_session_work',
        params: {...parameters, 'p_fingerprint': preview['fingerprint']},
      ) as String;
    } catch (_) {
      // Una confirmación perdida no obliga a adaptar otra vez ni a generar
      // una nueva huella sobre una pauta que ya ha cambiado por esta operación.
      try {
        final confirmed = await load(work.id);
        if (confirmed?.resultId case final result?) return result;
      } catch (_) {
        /* Se conserva el fallo original y la intención durable. */
      }
      rethrow;
    }
  }
}

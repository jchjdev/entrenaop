import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';

import '../../../pro/domain/pro_access.dart';

import '../../../workouts/data/models/workout_template_model.dart';
import '../../domain/entities/scheduled_workout_preview.dart';
import '../../domain/repositories/scheduled_workout_preview_repository.dart';
import '../models/scheduled_workout_model.dart';

class SupabaseScheduledWorkoutPreviewRepository
    implements ScheduledWorkoutPreviewRepository {
  const SupabaseScheduledWorkoutPreviewRepository(this.client, this.ownerId);

  final SupabaseClient client;
  final String ownerId;

  @override
  Future<ScheduledWorkoutPreview> get(String scheduledId) async {
    final response = await authenticatedTrainerRpc(
      client,
      ownerId,
      'get_scheduled_workout_preview',
      params: {'p_expected_owner': ownerId, 'p_scheduled_id': scheduledId},
    );
    final data = Map<String, dynamic>.from(response as Map);
    final scheduled = ScheduledWorkoutModel.fromJson(
      Map<String, dynamic>.from(data['scheduled_workout'] as Map),
    );
    final workout = WorkoutTemplateModel.fromJson(
      Map<String, dynamic>.from(data['template'] as Map),
    );
    final revision = data['revision'] as String;
    if (scheduled.id != scheduledId ||
        scheduled.templateId != workout.id ||
        scheduled.templateVersion != workout.version ||
        revision.isEmpty) {
      throw const FormatException('El entrenamiento no coincide con la pauta.');
    }
    return ScheduledWorkoutPreview(
      scheduled: scheduled,
      workout: workout,
      revision: revision,
      proRequired: data['pro_required'] == true,
    );
  }

  @override
  Future<String> startReviewed(String scheduledId, String revision) async {
    try {
      return await authenticatedTrainerRpc(
        client,
        ownerId,
        'start_reviewed_scheduled_workout',
        params: {
          'p_expected_owner': ownerId,
          'p_scheduled_id': scheduledId,
          'p_expected_revision': revision,
        },
      ) as String;
    } on PostgrestException catch (error) {
      final denied = ProAccessDenied.fromDetails(error.details);
      if (denied != null) throw denied;
      if (error.code == '40001') {
        throw const ScheduledWorkoutPreviewChanged();
      }
      rethrow;
    }
  }
}

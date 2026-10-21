import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_editor_ui/exercise_video_client.dart';

import 'trainer_workout_repository.dart' show trainerOperationId;

/// Adaptador profesional independiente de ADMIN y de la app del deportista.
class SupabaseTrainerVideoRepository extends ExerciseVideoClient {
  SupabaseTrainerVideoRepository(
    SupabaseClient client,
    String userId, {
    super.transport,
  }) : super(
         scope: 'trainer_exercise',
         operationId: trainerOperationId,
         checkIdentity: () => _identity(client, userId),
         call: (body) => _call(client, userId, body),
       );
  static void _identity(SupabaseClient client, String userId) {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('La cuenta ha cambiado.');
    }
  }

  static Future<Map<String, dynamic>> _call(
    SupabaseClient client,
    String userId,
    Map<String, Object?> body,
  ) async {
    _identity(client, userId);
    try {
      final response = await client.functions.invoke(
        'exercise-video',
        body: {...body, 'expected_user_id': userId},
      );
      _identity(client, userId);
      return Map<String, dynamic>.from(response.data as Map);
    } catch (_) {
      _identity(client, userId);
      rethrow;
    }
  }
}

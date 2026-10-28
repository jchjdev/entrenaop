import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/trainer_messages.dart';
import 'package:workout_editor_ui/exercise_video_client.dart';

/// Solo se expone reproducción en la UI móvil; el servidor autoriza cada recurso.
ExerciseVideoClient coachVideoSource(SupabaseClient client, String owner) {
  Session identity() {
    final session = client.auth.currentSession;
    if (session == null || session.user.id != owner || session.isExpired) {
      throw StateError('La cuenta ha cambiado o necesita renovar su sesión.');
    }
    return session;
  }

  return ExerciseVideoClient(
    scope: 'trainer_exercise',
    operationId: trainerMessageOperationId,
    checkIdentity: identity,
    call: (body) async {
      final token = identity().accessToken;
      try {
        final response = await client.functions.invoke(
          'exercise-video',
          body: {...body, 'expected_user_id': owner},
          headers: {'Authorization': 'Bearer $token'},
        );
        return Map<String, dynamic>.from(response.data as Map);
      } finally {
        identity();
      }
    },
  );
}

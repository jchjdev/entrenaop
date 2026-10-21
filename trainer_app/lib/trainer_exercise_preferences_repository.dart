import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainer_access/authenticated_rpc.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/exercise_preferences_client.dart';

import 'trainer_workout_repository.dart' show trainerOperationId;

class SupabaseTrainerExercisePreferences extends ExercisePreferencesClient {
  SupabaseTrainerExercisePreferences(SupabaseClient client, String userId)
    : super(
        context: ExercisePreferenceContext.trainerPrivate,
        operationId: trainerOperationId,
        isConflict: (error) =>
            error is PostgrestException && error.code == '40001',
        checkIdentity: () {
          if (client.auth.currentUser?.id != userId) {
            throw StateError('La cuenta ha cambiado.');
          }
        },
        call: (name, parameters) =>
            authenticatedTrainerRpc(client, userId, name, params: parameters),
      );
}

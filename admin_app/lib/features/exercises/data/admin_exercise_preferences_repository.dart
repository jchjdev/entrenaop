import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workout_core/exercise_catalog_preferences.dart';
import 'package:workout_editor_ui/exercise_preferences_client.dart';
import 'package:workout_editor_ui/guided_program_work.dart'
    show newGuidedWorkId;

/// Instancia de preferencias oficiales fijada a una cuenta y proyecto.
/// La identidad y el contexto se comprueban de nuevo en cada operación de servidor.
class SupabaseAdminExercisePreferencesRepository
    extends ExercisePreferencesClient {
  SupabaseAdminExercisePreferencesRepository(
    SupabaseClient client,
    String userId,
  ) : super(
        context: ExercisePreferenceContext.adminOfficial,
        operationId: newGuidedWorkId,
        isConflict: (error) =>
            error is PostgrestException && error.code == '40001',
        checkIdentity: () {
          if (client.auth.currentUser?.id != userId) {
            throw StateError('La cuenta ha cambiado.');
          }
        },
        call: (name, parameters) => client.rpc(name, params: parameters),
      );
}

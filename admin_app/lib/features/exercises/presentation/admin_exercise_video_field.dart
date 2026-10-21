import 'package:workout_editor_ui/exercise_video_field.dart';

/// ADMIN ofrece solo subida. Ocultar el enlace no elimina vídeos ya guardados.
class AdminExerciseVideoField extends ExerciseVideoField {
  const AdminExerciseVideoField({
    super.key,
    required super.controller,
    required super.repository,
    required super.onBusyChanged,
    super.pickVideo,
    super.onCoverReady,
    super.pickFrame,
  }) : super(allowExternalLinks: false);
}

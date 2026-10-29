import 'package:entrena_ui/entrena_ui.dart';
import 'package:flutter/material.dart';
import 'package:workout_core/exercise_draft.dart';
import 'package:workout_editor_ui/exercise_form.dart';
import 'package:workout_editor_ui/exercise_image_draft.dart';

import '../data/admin_exercise_repository.dart';
import '../data/admin_exercise_video_repository.dart';
import 'admin_exercise_video_field.dart';

/// El catálogo y la sesión usan el mismo formulario y la misma operación oficial.
Future<AdminCatalogExercise?> showAdminExerciseDialog(
  BuildContext context, {
  required AdminExerciseRepository repository,
  AdminExerciseVideoRepository? videos,
  AdminCatalogExercise? exercise,
}) async {
  String? savedId = exercise?.id;
  final result = await showDialog<ExerciseFormSubmission<ExerciseDraft>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ProfessionalWorkspaceViewport(
      builder: (_) => RetainedSaveDialog<ExerciseFormSubmission<ExerciseDraft>>(
        errorMessage: 'No se pudo guardar. Tus datos siguen aquí; comprueba el permiso y la conexión.',
        save: (submission) async {
          if (exercise == null) {
            savedId = await repository.createOfficial(
              submission.draft,
              image: submission.image,
            );
          } else {
            await repository.updateOfficial(
              exercise.id,
              submission.draft,
              image: submission.image,
              removeImage: submission.removeExistingImage,
            );
          }
        },
        builder: (context, submit, saving, error, markDirty) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ProfessionalWorkspaceScope.isDesktop(context)
                  ? 1060
                  : 620,
              maxHeight: 820,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (saving) const LinearProgressIndicator(),
                  Flexible(
                    child: AbsorbPointer(
                      absorbing: saving,
                      child: ExerciseForm(
                        title: exercise == null
                            ? 'Nuevo ejercicio oficial'
                            : 'Editar ejercicio oficial',
                        supportingText: exercise?.isPublic == false
                            ? 'Ejercicio retirado. Revisa su contenido: al guardar se publicará en el catálogo general de EntrenaOP.'
                            : 'Se publicará en el catálogo general de EntrenaOP.',
                        submitLabel: exercise == null
                            ? 'Crear ejercicio'
                            : !exercise.isPublic
                            ? 'Guardar y publicar'
                            : 'Guardar cambios',
                        fieldKeyPrefix: 'admin-exercise',
                        initialDraft: exercise?.toDraft(),
                        initialImageUrl: exercise?.imageUrl,
                        onSubmit: submit,
                        onDirtyChanged: markDirty,
                        videoFieldBuilder: (controller, busy, cover) =>
                            videos == null
                            ? const Text('Subida de vídeo no disponible.')
                            : AdminExerciseVideoField(
                                controller: controller,
                                repository: videos,
                                onBusyChanged: busy,
                                onCoverReady: cover,
                              ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (result == null) return null;
  final draft = ExerciseDraftValidator.normalizeAndValidate(result.draft);
  // El UUID se recibe de la escritura: una relectura fallida no crea otro ejercicio.
  // La miniatura nueva se resolverá al refrescar el catálogo, sin perder la identidad.
  return AdminCatalogExercise(
    id: savedId!,
    name: draft.name,
    description: draft.description,
    videoUrl: draft.videoUrl,
    muscleGroups: draft.muscleGroups,
    equipment: draft.equipment,
    difficulty: draft.difficulty,
    exerciseType: draft.exerciseType,
    imageUrl: result.image == null && !result.removeExistingImage
        ? exercise?.imageUrl
        : null,
    trainingProfile: exercise?.trainingProfile,
  );
}

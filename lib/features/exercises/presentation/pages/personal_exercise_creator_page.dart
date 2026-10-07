import 'dart:async';

import 'package:entrenaop/core/navigation/workflow_exit_guard.dart';

import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/usecases/create_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/update_exercise_usecase.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:workout_editor_ui/exercise_form.dart';
import 'package:workout_editor_ui/exercise_image_draft.dart';

class PersonalExerciseCreatorPage extends StatefulWidget {
  const PersonalExerciseCreatorPage({
    super.key,
    required this.createExercise,
    this.returnOnSave = false,
  }) : initialExercise = null,
       updateExercise = null;

  const PersonalExerciseCreatorPage.edit({
    super.key,
    required ExerciseEntity exercise,
    required UpdateExerciseUseCase update,
  }) : initialExercise = exercise,
       updateExercise = update,
       createExercise = null,
       returnOnSave = true;

  final CreateExerciseUseCase? createExercise;
  final UpdateExerciseUseCase? updateExercise;
  final ExerciseEntity? initialExercise;
  final bool returnOnSave;

  @override
  State<PersonalExerciseCreatorPage> createState() =>
      _PersonalExerciseCreatorPageState();
}

class _PersonalExerciseCreatorPageState
    extends State<PersonalExerciseCreatorPage> {
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  int _formVersion = 0;

  Future<void> _save(
    ExerciseFormSubmission<PersonalExerciseDraft> submission,
  ) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final original = widget.initialExercise;
      final draft = submission.draft;
      final String id;
      if (original == null) {
        final exercise = await widget.createExercise!(
          draft,
          image: submission.image,
        );
        id = exercise.id;
      } else {
        await widget.updateExercise!(
          ExerciseEntity(
            id: original.id,
            name: draft.name,
            description: draft.description,
            videoUrl: draft.videoUrl,
            muscleGroups: draft.muscleGroups,
            equipment: draft.equipment,
            difficulty: draft.difficulty,
            exerciseType: draft.exerciseType,
            isPublic: original.isPublic,
            origin: original.origin,
            createdBy: original.createdBy,
            thumbnailUrl: original.thumbnailUrl,
          ),
          image: submission.image,
          removeImage: submission.removeExistingImage,
        );
        id = original.id;
      }
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _saving = false;
      });
      if (widget.returnOnSave) {
        context.pop(id);
        return;
      }
      setState(() => _formVersion++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${draft.name} se ha guardado en tus ejercicios.'),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'No hemos podido guardar el ejercicio. Puedes reintentarlo.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkflowDraftGuard(
    hasUnsavedChanges: () => _dirty,
    isBusy: () => _saving,
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: Text(
        widget.initialExercise == null
            ? 'Crear ejercicio personal'
            : 'Editar ejercicio personal',
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Stack(
              children: [
                Column(
                  children: [
                    if (_error case final error?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: _saving,
                        child: ExerciseForm(
                          key: ValueKey(_formVersion),
                          initialDraft: widget.initialExercise == null
                              ? null
                              : PersonalExerciseDraft(
                                  name: widget.initialExercise!.name,
                                  description:
                                      widget.initialExercise!.description,
                                  videoUrl: widget.initialExercise!.videoUrl,
                                  muscleGroups:
                                      widget.initialExercise!.muscleGroups,
                                  equipment: widget.initialExercise!.equipment,
                                  difficulty:
                                      widget.initialExercise!.difficulty,
                                  exerciseType:
                                      widget.initialExercise!.exerciseType,
                                ),
                          initialImageUrl: widget.initialExercise?.thumbnailUrl,
                          autofocusName: widget.initialExercise == null,
                          title: widget.initialExercise == null
                              ? 'Nuevo ejercicio personal'
                              : 'Tu ejercicio',
                          supportingText: widget.initialExercise == null
                              ? 'Solo tú podrás verlo y utilizarlo en tus sesiones.'
                              : 'Los cambios se usarán en próximos entrenamientos. Los resultados anteriores se conservan.',
                          submitLabel: 'Guardar ejercicio',
                          fieldKeyPrefix: 'personal-exercise',
                          onSubmit: (draft) => unawaited(_save(draft)),
                          onDirtyChanged: (dirty) => _dirty = dirty,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_saving)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

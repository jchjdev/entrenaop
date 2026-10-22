import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:entrena_ui/entrena_ui.dart';
import 'package:workout_editor_ui/exercise_form.dart';
import 'package:workout_editor_ui/exercise_image_draft.dart';
import 'package:workout_editor_ui/workout_editor_exercise.dart';
import 'package:workout_editor_ui/workout_editor_initial_state.dart';
import 'package:workout_editor_ui/workout_editor_page.dart' as shared;
import 'package:workout_editor_ui/workout_editor_snapshot.dart';

import '../../../exercises/domain/entities/exercise_entity.dart';
import '../../../pro/domain/pro_access.dart';
import '../../../pro/presentation/widgets/pro_access_widgets.dart';
import '../../domain/entities/workout_template.dart';
import '../bloc/workout_editor_cubit.dart';
import '../bloc/workout_editor_state.dart';

/// Adaptador personal: catálogo, borrador por cuenta, permisos y guardado.
/// El formulario y la proyección de carrera/fuerza pertenecen al paquete común.
class PersonalWorkoutEditor extends StatefulWidget {
  const PersonalWorkoutEditor({super.key, required this.running});
  final bool running;
  @override
  State<PersonalWorkoutEditor> createState() => _PersonalWorkoutEditorState();
}

class _PersonalWorkoutEditorState extends State<PersonalWorkoutEditor> {
  bool _resolving = false, _ready = false;
  bool _leaving = false;
  String? _recoveryError;
  Map<String, dynamic>? _initial;
  CreatePersonalWorkoutInput _lastProjection = const CreatePersonalWorkoutInput(
    name: '',
    blocks: [],
  );

  void _initialize(WorkoutEditorState state) {
    if (_resolving || _ready || state.status != WorkoutEditorStatus.ready) {
      return;
    }
    _resolving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final cubit = context.read<WorkoutEditorCubit>();
        if (state.draft case final draft?) {
          final restore = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => EntrenaDialog(
              title: const Text('Borrador encontrado'),
              content: const Text(
                'Hay cambios de esta sesión guardados en este dispositivo.',
              ),
              actions: [
                EntrenaDialogActions(
                  primaryLabel: 'Recuperar',
                  onPrimary: () => Navigator.of(dialogContext).pop(true),
                  secondary: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Descartar'),
                    ),
                  ],
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (restore == true) {
            _lastProjection = draft.input;
            _initial =
                draft.editorState ??
                workoutEditorStateFromInput(draft.input).value;
            WorkoutEditorSnapshot(_initial!);
            if (_initial!['running'] != widget.running) {
              throw const FormatException(
                'El borrador pertenece a otra modalidad.',
              );
            }
          } else {
            await cubit.discardDraft();
          }
        }
        if (mounted) setState(() => _ready = true);
      } catch (_) {
        if (mounted) {
          setState(
            () => _recoveryError = 'Este borrador no es compatible con el editor actual. Se conserva sin sobrescribir.',
          );
        }
      }
    });
  }

  WorkoutEditorExercise _exercise(ExerciseEntity value) =>
      WorkoutEditorExercise(
        id: value.id,
        name: value.name,
        muscleGroups: value.muscleGroups,
        equipment: value.equipment,
        thumbnailUrl: value.thumbnailUrl,
        catalogScope: switch (value.origin) {
          ExerciseOrigin.system => 'EntrenaOP',
          ExerciseOrigin.user => 'Míos',
          ExerciseOrigin.coach => 'Preparador',
        },
      );

  Future<WorkoutEditorExercise?> _createExercise(
    BuildContext editorContext,
  ) async {
    final cubit = context.read<WorkoutEditorCubit>();
    final submission =
        await showModalBottomSheet<
          ExerciseFormSubmission<PersonalExerciseDraft>
        >(
          context: editorContext,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (sheetContext) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
              ),
              child: ExerciseForm(
                title: 'Nuevo ejercicio propio',
                supportingText:
                    'Será privado y solo aparecerá en tu biblioteca.',
                submitLabel: 'Crear y añadir',
                fieldKeyPrefix: 'personal-exercise',
                onSubmit: (value) => Navigator.of(sheetContext).pop(value),
              ),
            ),
          ),
        );
    if (submission == null || !mounted) return null;
    try {
      return _exercise(
        await cubit.createExercise(submission.draft, image: submission.image),
      );
    } on ProAccessDenied catch (error) {
      if (mounted) await showProRestriction(context, error);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<WorkoutEditorCubit, WorkoutEditorState>(
        listener: (context, state) {
          if (state.accessDenied case final error?) {
            unawaited(showProRestriction(context, error));
          }
          if (state.status == WorkoutEditorStatus.saved && !_leaving) {
            _leaving = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.pop(state.createdTemplateId);
            });
          }
        },
        builder: (context, state) {
          _initialize(state);
          if (_recoveryError case final message?) {
            return Scaffold(
              appBar: AppBar(title: const Text('Recuperar sesión')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(message),
                ),
              ),
            );
          }
          if (state.status == WorkoutEditorStatus.failure) {
            return Scaffold(
              appBar: AppBar(title: const Text('Crear sesión')),
              body: Center(
                child: FilledButton(
                  onPressed: context.read<WorkoutEditorCubit>().load,
                  child: const Text('Reintentar'),
                ),
              ),
            );
          }
          if (!_ready) {
            return const Scaffold(
              body: Center(child: Text('Preparando el editor…')),
            );
          }
          final cubit = context.read<WorkoutEditorCubit>();
          final revision = state.originalTemplate != null;
          return shared.WorkoutEditorPage(
            key: ValueKey('personal-${widget.running}'),
            originalTemplate: state.originalTemplate,
            initialEditorState: _initial,
            fixedRunningMode: widget.running,
            loadExercises: () async =>
                cubit.state.exercises.map(_exercise).toList(),
            onCreateExercise: _createExercise,
            saveLocalDraft: (raw) async {
              try {
                _lastProjection = projectWorkoutEditorSnapshot(
                  WorkoutEditorSnapshot(raw),
                );
              } on FormatException {
                // Los textos incompletos se guardan íntegros; no son una dosis nueva.
              }
              await cubit.persistEditorDraft(raw, _lastProjection);
            },
            onSave: (input) async {
              await cubit.save(input);
              if (cubit.state.status != WorkoutEditorStatus.saved) {
                throw FormatException(
                  cubit.state.errorMessage ?? 'No se pudo guardar la sesión.',
                );
              }
              return cubit.state.createdTemplateId!;
            },
            onSaved: (_) {},
            onClose: () => context.pop(),
            title: widget.running
                ? revision
                      ? 'Editar carrera'
                      : 'Nueva carrera'
                : revision
                ? 'Editar sesión'
                : 'Nueva sesión',
            heading: revision
                ? 'Crea una nueva versión'
                : 'Diseña tu entrenamiento',
            instructions: revision
                ? 'Tus entrenamientos anteriores conservan su versión. Borrador automático en este dispositivo.'
                : 'Sesión privada. Borrador automático en este dispositivo.',
            saveLabel: 'Guardar',
          );
        },
      );
}

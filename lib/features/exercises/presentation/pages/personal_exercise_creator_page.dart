import 'dart:async';

import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/usecases/create_exercise_usecase.dart';
import 'package:flutter/material.dart';
import 'package:workout_editor_ui/exercise_form.dart';

class PersonalExerciseCreatorPage extends StatefulWidget {
  const PersonalExerciseCreatorPage({super.key, required this.createExercise});

  final CreateExerciseUseCase createExercise;

  @override
  State<PersonalExerciseCreatorPage> createState() =>
      _PersonalExerciseCreatorPageState();
}

class _PersonalExerciseCreatorPageState
    extends State<PersonalExerciseCreatorPage> {
  bool _saving = false;
  int _formVersion = 0;

  Future<void> _save(PersonalExerciseDraft draft) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final exercise = await widget.createExercise(draft);
      if (!mounted) return;
      setState(() => _formVersion++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${exercise.name} se ha guardado en tus ejercicios.'),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hemos podido crear el ejercicio.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: const Text('Crear ejercicio personal'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Stack(
              children: [
                AbsorbPointer(
                  absorbing: _saving,
                  child: ExerciseForm(
                    key: ValueKey(_formVersion),
                    title: 'Nuevo ejercicio personal',
                    supportingText:
                        'Solo tú podrás verlo y utilizarlo en tus sesiones.',
                    submitLabel: 'Guardar ejercicio',
                    fieldKeyPrefix: 'personal-exercise',
                    onSubmit: (draft) => unawaited(_save(draft)),
                  ),
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

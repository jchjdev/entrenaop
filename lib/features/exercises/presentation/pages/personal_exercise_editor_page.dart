import 'package:entrenaop/features/exercises/domain/entities/exercise_entity.dart';
import 'package:entrenaop/features/exercises/domain/usecases/get_exercise_by_id_usecase.dart';
import 'package:entrenaop/features/exercises/domain/usecases/update_exercise_usecase.dart';
import 'package:entrenaop/features/exercises/presentation/pages/personal_exercise_creator_page.dart';
import 'package:flutter/material.dart';

class PersonalExerciseEditorPage extends StatefulWidget {
  const PersonalExerciseEditorPage({
    super.key,
    required this.exerciseId,
    required this.userId,
    required this.getExercise,
    required this.updateExercise,
  });
  final String exerciseId, userId;
  final GetExerciseByIdUseCase getExercise;
  final UpdateExerciseUseCase updateExercise;
  @override
  State<PersonalExerciseEditorPage> createState() =>
      _PersonalExerciseEditorPageState();
}

class _PersonalExerciseEditorPageState
    extends State<PersonalExerciseEditorPage> {
  late Future<ExerciseEntity?> _exercise;
  @override
  void initState() {
    super.initState();
    _exercise = widget.getExercise(widget.exerciseId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ExerciseEntity?>(
    future: _exercise,
    builder: (context, snapshot) {
      final exercise = snapshot.data;
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          exercise != null &&
          exercise.origin == ExerciseOrigin.user &&
          !exercise.isPublic &&
          exercise.createdBy == widget.userId) {
        return PersonalExerciseCreatorPage.edit(
          exercise: exercise,
          update: widget.updateExercise,
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Editar ejercicio personal')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: snapshot.connectionState != ConnectionState.done
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.hasError
                            ? 'No hemos podido cargar el ejercicio.'
                            : 'Este ejercicio no está disponible para editar.',
                      ),
                      if (snapshot.hasError)
                        TextButton(
                          onPressed: () => setState(() {
                            _exercise = widget.getExercise(widget.exerciseId);
                          }),
                          child: const Text('Reintentar'),
                        ),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}

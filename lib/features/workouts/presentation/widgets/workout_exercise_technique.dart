import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/workout_execution.dart';
import '../bloc/active_workout_cubit.dart';
import '../../../exercises/presentation/widgets/exercise_detail_sheet.dart';

Future<void> showWorkoutTechnique(
  BuildContext context,
  WorkoutExecutionSet set,
) {
  final exercise = context
      .read<ActiveWorkoutCubit>()
      .state
      .exercises[set.exerciseId];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ExerciseDetailSheet(
      name: set.exerciseName,
      description: set.exerciseDescription ?? exercise?.description,
      imageUrl: exercise?.thumbnailUrl,
      videoUrl: set.exerciseVideoUrl ?? exercise?.videoUrl,
      muscleGroups: exercise?.muscleGroups ?? const [],
      equipment: exercise?.equipment ?? const [],
    ),
  );
}

import 'package:flutter/material.dart';

import 'personal_workout_editor.dart';

class WorkoutEditorPage extends StatelessWidget {
  const WorkoutEditorPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const PersonalWorkoutEditor(running: false);
}

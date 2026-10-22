import 'package:flutter/material.dart';

import 'personal_workout_editor.dart';

class RunningWorkoutEditorPage extends StatelessWidget {
  const RunningWorkoutEditorPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const PersonalWorkoutEditor(running: true);
}

import 'package:flutter/material.dart';
import 'package:workout_editor_ui/program_session_picker.dart';

import '../../workouts/data/admin_workout_repository.dart';
import '../../workouts/presentation/admin_session_library_status.dart';

/// Conserva la entrada oficial para consumidores existentes del selector.
class GuidedSessionPicker extends StatelessWidget {
  const GuidedSessionPicker({super.key, required this.sessions});
  final List<AdminWorkoutSummary> sessions;
  @override
  Widget build(BuildContext context) => ProgramSessionPicker(
    sessions: sessions,
    statusBuilder: (session) => AdminSessionLibraryStatus(session: session),
  );
}

import 'package:equatable/equatable.dart';

enum WorkoutCue { preparationTick, workStarted, workFinished, restFinished }

class WorkoutCuePreferences extends Equatable {
  const WorkoutCuePreferences({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  final bool soundEnabled;
  final bool hapticsEnabled;

  @override
  List<Object?> get props => [soundEnabled, hapticsEnabled];
}

abstract class WorkoutCueService {
  WorkoutCuePreferences get preferences;

  Future<void> savePreferences(WorkoutCuePreferences preferences);

  Future<void> signal(WorkoutCue cue);
}

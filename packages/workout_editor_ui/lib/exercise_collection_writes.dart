import 'exercise_preferences_controller.dart';

typedef ExerciseCollectionWrite = ({
  String id,
  String operationId,
  int revision,
  List<String> labels,
});

class ExerciseCollectionWrites {
  ExerciseCollectionWrites(this.preferences, this.writes);

  final ExercisePreferencesController preferences;
  final List<ExerciseCollectionWrite> writes;
  int confirmed = 0;

  Future<void> save({required bool Function() isActive}) async {
    while (confirmed < writes.length && isActive()) {
      final write = writes[confirmed];
      await preferences.saveLabels(
        write.id,
        write.labels,
        write.revision,
        write.operationId,
      );
      confirmed++;
    }
  }
}

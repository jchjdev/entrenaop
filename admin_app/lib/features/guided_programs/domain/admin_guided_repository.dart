import 'package:workout_core/guided_program.dart';
import 'package:workout_core/workout_template.dart';

abstract class AdminGuidedRepository {
  Future<List<GuidedProgram>> programs();
  Future<GuidedProgram> program(String id);
  Future<String> save(GuidedProgram program, {String? id});
  Future<void> setStatus(String id, String status);
  Future<List<GuidedWarmup>> warmups();
  Future<String> saveWarmup(
    CreatePersonalWorkoutInput input, {
    String? previousId,
  });
}

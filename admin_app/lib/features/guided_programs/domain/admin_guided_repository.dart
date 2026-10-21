import 'package:workout_core/guided_program.dart';
import 'package:workout_core/workout_template.dart';

import 'package:workout_editor_ui/guided_program_editor_adapter.dart';

abstract class AdminGuidedRepository
    implements GuidedProgramCompositionRepository {
  Future<List<GuidedProgram>> programs();
  @override
  Future<List<GuidedProgramCategory>> categories();
  Future<GuidedProgramCategory> saveCategory(
    String name, {
    GuidedProgramCategory? original,
    bool active = true,
  });
  Future<GuidedProgram> program(String id);
  @override
  Future<String> save(GuidedProgram program, {String? id});
  Future<void> setStatus(String id, String status);
  @override
  Future<List<GuidedWarmup>> warmups();
  Future<String> saveWarmup(
    CreatePersonalWorkoutInput input, {
    String? previousId,
  });
}

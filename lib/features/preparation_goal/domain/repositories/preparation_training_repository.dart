import 'package:workout_core/strength_exercise_catalog.dart';

import '../entities/adaptive_program_progress.dart';
import '../entities/training_scope.dart';
import '../entities/adaptive_program_path.dart';

/// Los mapas conservan las instantáneas versionadas del servidor. Este contrato
/// no expone el cliente de red ni permite que la pantalla calcule progresiones.
class PreparationTrainingData {
  const PreparationTrainingData({
    this.hasRunning = false,
    bool? availableRunning,
    this.availablePerformance = true,
    this.trainingScope = TrainingScope.full,
    this.activeProgram,
    this.programName,
    this.targetDate,
    this.programState = const {},
    this.pendingSessions = const [],
    this.canResetTrial = false,
    this.updateOptions = const {},
    this.programPath = const AdaptiveProgramPath(),
    this.calibrationOptions = const [],
    required this.catalog,
    required this.context,
    required this.runningContext,
    required this.references,
    required this.objectives,
    required this.relations,
    required this.publishedWeeks,
  }) : availableRunning = availableRunning ?? hasRunning;
  final bool availableRunning;
  final bool availablePerformance;
  final TrainingScope trainingScope;
  final Map<String, dynamic>? activeProgram;
  final String? programName;
  final bool hasRunning;
  final bool canResetTrial;
  final Map<String, dynamic> updateOptions;
  final AdaptiveProgramPath programPath;
  final List<Map<String, dynamic>> calibrationOptions;
  final DateTime? targetDate;
  final Map<String, dynamic> programState;
  final List<Map<String, dynamic>> pendingSessions;
  final List<StrengthExerciseDefinition> catalog;
  final Map<String, dynamic>? context;
  final Map<String, dynamic>? runningContext;
  final List<Map<String, dynamic>> references;
  final List<Map<String, dynamic>> objectives;
  final List<Map<String, dynamic>> relations;
  final List<DateTime> publishedWeeks;
}

abstract interface class PreparationTrainingRepository {
  /// Una ejecución de cualquier preparación puede bloquear el cambio de programa.
  Future<String?> getInProgressExecutionId();
  Future<void> pause(String goalId);
  Future<void> resetTrial(String goalId, String confirmation);
  Future<List<AdaptiveProgramProgress>> refreshPrograms();
  Future<void> skipSession(String id);
  Future<void> saveProgram(
    String goalId,
    DateTime targetDate,
    Map<String, dynamic> targets, {
    TrainingScope scope = TrainingScope.full,
  });
  Future<void> advance(String goalId);
  Future<Map<String, dynamic>> activate(
    String goalId,
    DateTime week,
    Map<String, dynamic> reviewed,
  );
  Future<PreparationTrainingData> load(String goalId);
  Future<void> saveContext(
    Map<String, int> availability,
    Set<String> equipment, {
    required bool reportsPain,
    required bool capacityConfirmed,
  });
  Future<void> saveReference(
    String goalId,
    Map<String, dynamic> reference, {
    String? testId,
  });
  Future<void> deactivateReference(String id);
  Future<Map<String, dynamic>> calculate(
    String goalId,
    DateTime week, {
    bool revise = false,
    bool activation = false,
  });
  Future<Map<String, dynamic>> publish(
    String goalId,
    DateTime week,
    Map<String, dynamic> reviewed,
  );
}

class PreparationTrainingException implements Exception {
  const PreparationTrainingException(this.message);
  final String message;
  @override
  String toString() => message;
}

import 'package:workout_core/workout_template.dart';

class ProgramSessionSummary {
  const ProgramSessionSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.version,
    required this.isRunning,
    required this.catalogScope,
    this.guidedPrograms = const [],
    this.hasWarmup = false,
    this.supportsAdjustableRest = true,
    this.showInLibrary = true,
  });

  final String id;
  final String name;
  final String status;
  final int version;
  final bool isRunning;
  final String catalogScope;
  final List<ProgramSessionUsage> guidedPrograms;
  final bool hasWarmup, supportsAdjustableRest;
  final bool showInLibrary;

  ProgramSessionSummary withLibraryVisibility(bool value) =>
      ProgramSessionSummary(
        id: id,
        name: name,
        status: status,
        version: version,
        isRunning: isRunning,
        catalogScope: catalogScope,
        guidedPrograms: guidedPrograms,
        hasWarmup: hasWarmup,
        supportsAdjustableRest: supportsAdjustableRest,
        showInLibrary: value,
      );
}

class ProgramSessionUsage {
  const ProgramSessionUsage({
    required this.id,
    required this.name,
    required this.version,
    required this.status,
  });

  final String id, name, status;
  final int version;
}

abstract interface class ProgramSessionCatalog {
  Future<List<ProgramSessionSummary>> listGeneral();
  Future<WorkoutTemplate?> getTemplateById(String id);
  Future<void> setLibraryVisibility(
    String id,
    bool value, {
    required bool expected,
  });
}

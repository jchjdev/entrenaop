/// Proyección y estado real publicados por el servidor; no calcula fases.
class AdaptiveProgramPath {
  const AdaptiveProgramPath({
    this.stages = const [],
    this.objectives = const [],
    this.note = '',
  });
  factory AdaptiveProgramPath.fromJson(Map<String, dynamic> json) =>
      AdaptiveProgramPath(
        stages: _rows(json['stages'])
            .map(ProgramStage.fromJson)
            .toList(growable: false),
        objectives: _rows(json['objectives'])
            .map(ProgramObjectivePhase.fromJson)
            .toList(growable: false),
        note: json['note'] as String? ?? '',
      );
  final List<ProgramStage> stages;
  final List<ProgramObjectivePhase> objectives;
  final String note;
  bool get isEmpty => stages.isEmpty && objectives.isEmpty;
  static List<Map<String, dynamic>> _rows(Object? value) =>
      (value as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
}

class ProgramStage {
  const ProgramStage({
    required this.code,
    required this.name,
    required this.purpose,
    this.startsOn,
    this.endsOn,
  });
  factory ProgramStage.fromJson(Map<String, dynamic> json) => ProgramStage(
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    purpose: json['purpose'] as String? ?? '',
    startsOn: DateTime.tryParse(json['starts_on'] as String? ?? ''),
    endsOn: DateTime.tryParse(json['ends_on'] as String? ?? ''),
  );
  final String code, name, purpose;
  final DateTime? startsOn, endsOn;
}

class ProgramObjectivePhase {
  const ProgramObjectivePhase({
    required this.code,
    required this.name,
    required this.exerciseName,
    required this.purpose,
    required this.nextReview,
  });
  factory ProgramObjectivePhase.fromJson(Map<String, dynamic> json) =>
      ProgramObjectivePhase(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        exerciseName: json['exercise_name'] as String? ?? '',
        purpose: json['purpose'] as String? ?? '',
        nextReview: json['next_review'] as String? ?? '',
      );
  final String code, name, exerciseName, purpose, nextReview;
}

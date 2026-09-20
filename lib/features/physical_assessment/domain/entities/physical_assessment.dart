import 'package:equatable/equatable.dart';

// Representa las columnas H/M del baremo oficial, no la identidad de género
// almacenada en el perfil de la persona.
enum AssessmentCategory { men, women }

enum AssessmentMilestone { entry, endOfGeneralMilitaryTraining, endOfTraining }

enum MarkUnit { repetitions, milliseconds }

enum BetterDirection { higher, lower }

class PhysicalTestDefinition extends Equatable {
  const PhysicalTestDefinition({
    required this.id,
    required this.name,
    required this.unit,
    required this.betterDirection,
  });

  final String id;
  final String name;
  final MarkUnit unit;
  final BetterDirection betterDirection;

  @override
  List<Object> get props => [id, name, unit, betterDirection];
}

class AssessmentStandard extends Equatable {
  const AssessmentStandard({
    required this.catalogVersion,
    required this.test,
    required this.category,
    required this.milestone,
    required this.threshold,
  }) : assert(threshold >= 0);

  final String catalogVersion;
  final PhysicalTestDefinition test;
  final AssessmentCategory category;
  final AssessmentMilestone milestone;
  final int threshold;

  @override
  List<Object> get props => [
    catalogVersion,
    test,
    category,
    milestone,
    threshold,
  ];
}

class RecordedMark extends Equatable {
  const RecordedMark({
    required this.testId,
    required this.unit,
    required this.value,
  }) : assert(value >= 0);

  final String testId;
  final MarkUnit unit;
  final int value;

  @override
  List<Object> get props => [testId, unit, value];
}

class AssessmentResult extends Equatable {
  const AssessmentResult({
    required this.passed,
    required this.mark,
    required this.standard,
  });

  final bool passed;
  final RecordedMark mark;
  final AssessmentStandard standard;

  @override
  List<Object> get props => [passed, mark, standard];
}

class AssessmentReport extends Equatable {
  AssessmentReport({
    required this.catalogVersion,
    required this.category,
    required this.milestone,
    required List<AssessmentResult> results,
  }) : assert(results.isNotEmpty),
       results = List.unmodifiable(results);

  final String catalogVersion;
  final AssessmentCategory category;
  final AssessmentMilestone milestone;
  final List<AssessmentResult> results;

  bool get passedOverall => results.every((result) => result.passed);

  int get passedTests => results.where((result) => result.passed).length;

  @override
  List<Object> get props => [catalogVersion, category, milestone, results];
}

class PhysicalAssessmentHistoryEntry extends Equatable {
  const PhysicalAssessmentHistoryEntry({
    required this.id,
    required this.completedAt,
    required this.report,
  });

  final String id;
  final DateTime completedAt;
  final AssessmentReport report;

  @override
  List<Object> get props => [id, completedAt, report];
}

class AssessmentProgress extends Equatable {
  const AssessmentProgress({
    required this.test,
    required this.previousValue,
    required this.currentValue,
    required this.favorableDifference,
  });

  final PhysicalTestDefinition test;
  final int previousValue;
  final int currentValue;

  // Un valor positivo siempre representa mejora, aunque en las pruebas
  // cronometradas mejorar signifique reducir el tiempo.
  final int favorableDifference;

  bool get improved => favorableDifference > 0;
  bool get unchanged => favorableDifference == 0;

  @override
  List<Object> get props => [
    test,
    previousValue,
    currentValue,
    favorableDifference,
  ];
}

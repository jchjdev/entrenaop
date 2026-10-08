import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';

class MeasurementSample {
  const MeasurementSample({
    required this.id,
    required this.completedAt,
    required this.value,
    this.context,
  });

  final String id;
  final DateTime completedAt;
  final int value;
  final String? context;
}

/// Una serie contiene exclusivamente marcas del mismo contrato de medición.
/// La clave distingue origen, prueba, versión, unidad y contexto de evaluación.
class MeasurementSeries {
  MeasurementSeries({
    required this.id,
    required this.test,
    required this.origin,
    required this.version,
    required List<MeasurementSample> samples,
  }) : samples = List.unmodifiable(
         [...samples]..sort((a, b) {
           final date = b.completedAt.compareTo(a.completedAt);
           return date == 0 ? b.id.compareTo(a.id) : date;
         }),
       );

  final String id;
  final PhysicalTestDefinition test;
  final String origin;
  final String version;
  final List<MeasurementSample> samples;

  List<MeasurementSample> earlierThan(MeasurementSample current) => samples
      .where((sample) => sample.completedAt.isBefore(current.completedAt))
      .toList(growable: false);

  bool get canCompare =>
      samples.length > 1 && earlierThan(samples.first).isNotEmpty;

  AssessmentProgress? compare({
    required String previousId,
    required String currentId,
  }) {
    final previous = samples.where((s) => s.id == previousId).singleOrNull;
    final current = samples.where((s) => s.id == currentId).singleOrNull;
    if (previous == null ||
        current == null ||
        !previous.completedAt.isBefore(current.completedAt)) {
      return null;
    }
    return AssessmentProgress(
      test: test,
      previousValue: previous.value,
      currentValue: current.value,
      favorableDifference: test.betterDirection == BetterDirection.higher
          ? current.value - previous.value
          : previous.value - current.value,
    );
  }
}

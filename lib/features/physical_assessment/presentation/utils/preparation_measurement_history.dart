import 'dart:convert';

import 'package:entrenaop/features/physical_assessment/data/repositories/fas_periodic_assessment_repository.dart';
import 'package:entrenaop/features/physical_assessment/domain/catalogs/fas_periodic_2027_reference.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/measurement_history.dart';
import 'package:entrenaop/features/physical_assessment/domain/entities/physical_assessment.dart';
import 'package:entrenaop/features/preparation_goal/domain/entities/running_test_result.dart';

/// Adapta hechos históricos al comparador; no consulta el catálogo editorial
/// vigente, no recalcula puntuaciones ni reúne controles con pruebas oficiales.
List<MeasurementSeries> preparationMeasurementHistory({
  List<PhysicalAssessmentHistoryEntry> troop = const [],
  List<FasPeriodicAssessmentEntry> fas = const [],
  List<RunningTestResult> running = const [],
  FasPeriodic2027Reference? fasReference,
}) {
  final groups = <String, _SeriesBuilder>{};
  void add({
    required List<String> contract,
    required PhysicalTestDefinition test,
    required String origin,
    required String version,
    required MeasurementSample sample,
  }) {
    if (sample.value < 0 || sample.id.isEmpty || version.trim().isEmpty) return;
    final key = jsonEncode([
      ...contract,
      test.id,
      test.unit.name,
      test.betterDirection.name,
    ]);
    final builder = groups.putIfAbsent(
      key,
      () => _SeriesBuilder(test, origin, version),
    );
    builder.samples.add(sample);
  }

  for (final entry in troop) {
    final report = entry.report;
    for (final result in report.results) {
      final standard = result.standard;
      final test = standard.test;
      if (result.mark.testId != test.id ||
          result.mark.unit != test.unit ||
          standard.catalogVersion != report.catalogVersion ||
          standard.category != report.category ||
          standard.milestone != report.milestone) {
        continue;
      }
      final milestone = switch (report.milestone) {
        AssessmentMilestone.entry => 'Ingreso',
        AssessmentMilestone.endOfGeneralMilitaryTraining =>
          'Fin de formación general',
        AssessmentMilestone.endOfTraining => 'Fin de formación',
      };
      final column = report.category == AssessmentCategory.men ? 'H' : 'M';
      add(
        contract: [
          'troop',
          report.catalogVersion,
          report.category.name,
          report.milestone.name,
        ],
        test: test,
        origin: 'Evaluación · $milestone · $column',
        version: report.catalogVersion,
        sample: MeasurementSample(
          id: entry.id,
          completedAt: entry.completedAt,
          value: result.mark.value,
        ),
      );
    }
  }

  if (fasReference != null) {
    for (final entry in fas) {
      // Las versiones oficiales antiguas no conservan un protocolo separado.
      // Solo esta versión íntegra permite resolver la dirección y la unidad.
      if (entry.scoringVersion != FasPeriodic2027Reference.version ||
          !['men', 'women'].contains(entry.category)) {
        continue;
      }
      for (final mark in entry.marks) {
        try {
          final definition = fasReference.passMarkFor(
            testId: mark.testId,
            category: AssessmentCategory.values.byName(entry.category),
            age: entry.age,
          );
          if (definition == null || definition.unit.name != mark.unit) continue;
          add(
            contract: ['fas', entry.scoringVersion, entry.category],
            test: PhysicalTestDefinition(
              id: mark.testId,
              name: mark.testName,
              unit: definition.unit,
              betterDirection: definition.betterDirection,
            ),
            origin: 'Evaluación FAS · ${entry.category == 'men' ? 'H' : 'M'}',
            version: entry.scoringVersion,
            sample: MeasurementSample(
              id: entry.id,
              completedAt: entry.completedAt,
              value: mark.value,
              context: '${entry.age} años',
            ),
          );
        } on ArgumentError {
          // Una prueba o edad ajena al catálogo no vuelve comparable el registro.
        }
      }
    }
  }

  for (final result in running) {
    if (result.protocolVersion != 'run_2000m_v1' ||
        result.id == null ||
        result.validate() != null) {
      continue;
    }
    add(
      contract: ['running-control', result.protocolVersion],
      test: const PhysicalTestDefinition(
        id: 'run_2000_m',
        name: 'Control de 2 km',
        unit: MarkUnit.milliseconds,
        betterDirection: BetterDirection.lower,
      ),
      origin: 'Control de carrera',
      version: result.protocolVersion,
      sample: MeasurementSample(
        id: result.id!,
        completedAt: result.completedAt,
        value: result.durationSeconds * 1000,
        context: 'RPE ${result.rpe}',
      ),
    );
  }

  final ordered =
      [
        for (final entry in groups.entries.indexed)
          (
            entry.$1,
            MeasurementSeries(
              id: entry.$2.key,
              test: entry.$2.value.test,
              origin: entry.$2.value.origin,
              version: entry.$2.value.version,
              samples: entry.$2.value.samples,
            ),
          ),
      ]..sort((a, b) {
        final comparable =
            (b.$2.canCompare ? 1 : 0) - (a.$2.canCompare ? 1 : 0);
        return comparable != 0 ? comparable : a.$1.compareTo(b.$1);
      });
  return [for (final entry in ordered) entry.$2];
}

class _SeriesBuilder {
  _SeriesBuilder(this.test, this.origin, this.version);
  final PhysicalTestDefinition test;
  final String origin;
  final String version;
  final List<MeasurementSample> samples = [];
}

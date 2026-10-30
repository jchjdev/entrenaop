import 'dart:convert';
import 'dart:math' as math;

import 'running_step.dart';
import 'running_step_codec.dart';
import 'workout_result_review.dart';

/// Proyección de consulta. Conserva huecos y posiciones: no completa resultados.
class RunningPaceSample {
  const RunningPaceSample({
    required this.review,
    this.kind,
    this.recoveryType,
    this.restAfterSeconds,
  });
  final ReviewSet review;
  final RunningStepKind? kind;
  final String? recoveryType;
  final num? restAfterSeconds;

  bool get effort => kind == RunningStepKind.run;
  num? get distance => _positive(review.actual['distance']);
  num? get duration => _positive(review.actual['time']);
  num? get pace =>
      review.status == 'completed' && distance != null && duration != null
      ? _positive(review.actual['pace'])
      : null;
  num? get targetMin => _positive(review.targets['paceMin']);
  num? get targetMax => _positive(review.targets['paceMax']) ?? targetMin;
  bool get hasTarget =>
      targetMin != null && targetMax != null && targetMax! >= targetMin!;

  /// Se comparan recetas equivalentes dentro del mismo bloque, con distancia
  /// completada dentro del 1 % del objetivo. Una serie parcial no entra al grupo.
  String? get comparisonKey {
    final targetDistance = _positive(review.targets['distance']);
    if (!effort ||
        pace == null ||
        !hasTarget ||
        targetDistance == null ||
        review.block == null ||
        (distance! - targetDistance).abs() > targetDistance * .01) {
      return null;
    }
    return jsonEncode([
      review.block,
      targetDistance.toDouble(),
      targetMin!.toDouble(),
      targetMax!.toDouble(),
      review.targets['time']?.toDouble(),
      review.targets['recoveryTime']?.toDouble(),
      review.targets['recoveryDistance']?.toDouble(),
      recoveryType,
      restAfterSeconds?.toDouble(),
    ]);
  }
}

class RunningPaceGroup {
  RunningPaceGroup(this.key, Iterable<RunningPaceSample> samples)
    : samples = List.unmodifiable(samples);
  final String key;
  final List<RunningPaceSample> samples;
  num get spread =>
      samples.map((s) => s.pace!).reduce(math.max) -
      samples.map((s) => s.pace!).reduce(math.min);
  num get firstLastDelta => samples.last.pace! - samples.first.pace!;
}

class RunningPaceSummary {
  factory RunningPaceSummary(Iterable<RunningPaceSample> samples) {
    final measured = samples.where((s) => s.pace != null).toList();
    if (measured.isEmpty) {
      return const RunningPaceSummary._(0, null, null, null);
    }
    // Media ponderada por distancia: una serie de 200 m no pesa como una de 1 km.
    final distance = measured.fold<num>(0, (v, s) => v + s.distance!);
    final duration = measured.fold<num>(0, (v, s) => v + s.duration!);
    return RunningPaceSummary._(
      measured.length,
      duration * 1000 / distance,
      measured.reduce((a, b) => a.pace! <= b.pace! ? a : b),
      measured.reduce((a, b) => a.pace! >= b.pace! ? a : b),
    );
  }
  const RunningPaceSummary._(this.count, this.mean, this.fastest, this.slowest);
  final int count;
  final num? mean;
  final RunningPaceSample? fastest, slowest;
}

class RunningPaceAnalysis {
  RunningPaceAnalysis(Iterable<RunningPaceSample> samples)
    : samples = _ordered(samples);

  factory RunningPaceAnalysis.fromRows(Iterable<Map<String, dynamic>> rows) =>
      RunningPaceAnalysis([
        for (final row in rows)
          if (row['block_format'] == 'running')
            RunningPaceSample(
              review: reviewSetFromJson(row),
              kind: _kind(row['running_step']),
              recoveryType: row['recovery_type'] as String?,
              restAfterSeconds: row['rest_after_seconds'] as num?,
            ),
      ]);
  final List<RunningPaceSample> samples;
  bool get hasEfforts => samples.any((s) => s.effort);
  bool get hasUnclassified => samples.any((s) => s.kind == null);

  List<RunningPaceGroup> get groups {
    final grouped = <String, List<RunningPaceSample>>{};
    for (final sample in samples) {
      final key = sample.comparisonKey;
      if (key != null) (grouped[key] ??= []).add(sample);
    }
    final groups = [
      for (final entry in grouped.entries)
        if (entry.value.length >= 2) RunningPaceGroup(entry.key, entry.value),
    ];
    // El grupo mayor se propone primero; los empates conservan el orden de sesión.
    groups.sort((a, b) {
      final count = b.samples.length.compareTo(a.samples.length);
      return count != 0
          ? count
          : samples
                .indexOf(a.samples.first)
                .compareTo(samples.indexOf(b.samples.first));
    });
    return groups;
  }
}

num? _positive(num? value) =>
    value != null && value.isFinite && value > 0 ? value : null;

RunningStepKind? _kind(Object? value) {
  // Los registros antiguos o de otra versión se muestran sin atribuirles una fase.
  try {
    return RunningStepCodec.decode(value)?.kind;
  } on FormatException {
    return null;
  }
}

List<RunningPaceSample> _ordered(Iterable<RunningPaceSample> source) {
  final indexed = source
      .where((s) => s.review.format == 'running')
      .indexed
      .toList();
  indexed.sort((a, b) {
    for (final pair in [
      (a.$2.review.block, b.$2.review.block),
      (a.$2.review.item, b.$2.review.item),
      (a.$2.review.order, b.$2.review.order),
    ]) {
      final compared = (pair.$1 ?? 0x7fffffff).compareTo(pair.$2 ?? 0x7fffffff);
      if (compared != 0) return compared;
    }
    return a.$1.compareTo(b.$1);
  });
  return List.unmodifiable(indexed.map((entry) => entry.$2));
}

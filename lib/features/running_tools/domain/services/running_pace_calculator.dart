class RunningPaceCalculator {
  const RunningPaceCalculator();

  static const maxDistanceMeters = 100000;

  int automaticSplitMeters(double distanceMeters) {
    if (distanceMeters <= 200) return distanceMeters.ceil();
    if (distanceMeters <= 500) return 100;
    if (distanceMeters <= 1000) return 200;
    if (distanceMeters <= 2000) return 400;
    return 1000;
  }

  RunningPaceCalculation calculate({
    required int paceSecondsPerKilometer,
    required double distanceMeters,
    required int splitMeters,
  }) {
    if (paceSecondsPerKilometer <= 0) {
      throw ArgumentError.value(
        paceSecondsPerKilometer,
        'paceSecondsPerKilometer',
        'El ritmo debe ser mayor que cero.',
      );
    }
    if (!distanceMeters.isFinite ||
        distanceMeters < 1 ||
        distanceMeters > maxDistanceMeters) {
      throw ArgumentError.value(
        distanceMeters,
        'distanceMeters',
        'La distancia debe estar entre 1 m y 100 km.',
      );
    }
    if (splitMeters <= 0) {
      throw ArgumentError.value(
        splitMeters,
        'splitMeters',
        'El parcial debe ser mayor que cero.',
      );
    }

    final distances = <double>[
      for (
        var distance = splitMeters;
        distance < distanceMeters;
        distance += splitMeters
      )
        distance.toDouble(),
      distanceMeters,
    ];
    var previousDistance = 0.0;
    var previousCumulativeSeconds = 0;
    final splits = distances
        .map((distance) {
          // Redondear cada paso acumulado reparte los segundos sobrantes sin que
          // la suma de los tramos deje de coincidir con el tiempo final.
          final cumulativeSeconds = (paceSecondsPerKilometer * distance / 1000)
              .round();
          final split = RunningPaceSplit(
            distanceMeters: distance,
            segmentMeters: distance - previousDistance,
            segmentSeconds: cumulativeSeconds - previousCumulativeSeconds,
            cumulativeSeconds: cumulativeSeconds,
          );
          previousDistance = distance;
          previousCumulativeSeconds = cumulativeSeconds;
          return split;
        })
        .toList(growable: false);

    return RunningPaceCalculation(
      paceSecondsPerKilometer: paceSecondsPerKilometer,
      distanceMeters: distanceMeters,
      splitMeters: splitMeters,
      totalSeconds: splits.last.cumulativeSeconds,
      splits: splits,
    );
  }
}

class RunningPaceCalculation {
  const RunningPaceCalculation({
    required this.paceSecondsPerKilometer,
    required this.distanceMeters,
    required this.splitMeters,
    required this.totalSeconds,
    required this.splits,
  });

  final int paceSecondsPerKilometer;
  final double distanceMeters;
  final int splitMeters;
  final int totalSeconds;
  final List<RunningPaceSplit> splits;
}

class RunningPaceSplit {
  const RunningPaceSplit({
    required this.distanceMeters,
    required this.segmentMeters,
    required this.segmentSeconds,
    required this.cumulativeSeconds,
  });

  final double distanceMeters;
  final double segmentMeters;
  final int segmentSeconds;
  final int cumulativeSeconds;
}

class RunningPaceCalculator {
  const RunningPaceCalculator();

  RunningPaceCalculation calculate({
    required int paceSecondsPerKilometer,
    required int distanceMeters,
    required int splitMeters,
  }) {
    if (paceSecondsPerKilometer <= 0) {
      throw ArgumentError.value(
        paceSecondsPerKilometer,
        'paceSecondsPerKilometer',
        'El ritmo debe ser mayor que cero.',
      );
    }
    if (distanceMeters < 1 || distanceMeters > 2000) {
      throw ArgumentError.value(
        distanceMeters,
        'distanceMeters',
        'La distancia debe estar entre 1 y 2000 metros.',
      );
    }
    if (splitMeters <= 0) {
      throw ArgumentError.value(
        splitMeters,
        'splitMeters',
        'El parcial debe ser mayor que cero.',
      );
    }

    final distances = <int>[
      for (
        var distance = splitMeters;
        distance < distanceMeters;
        distance += splitMeters
      )
        distance,
      distanceMeters,
    ];
    var previousDistance = 0;
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
  final int distanceMeters;
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

  final int distanceMeters;
  final int segmentMeters;
  final int segmentSeconds;
  final int cumulativeSeconds;
}

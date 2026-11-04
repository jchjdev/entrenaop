import 'dart:math' as math;

enum PullGear {
  bands('Barra y gomas'),
  machine('Barra y máquina asistida'),
  feet('Barra baja con apoyo de pies'),
  rows('Barra baja solo para australianas'),
  step('Barra y escalón estable'),
  bar('Solo barra alta'),
  none('Sin material');

  const PullGear(this.label);
  final String label;

  bool get canTest => this != rows && this != none;
  bool get hasAssistance => this == bands || this == machine || this == feet;
}

enum PullCalendar {
  strength('Solo fuerza'),
  combined('Fuerza y carrera'),
  tight('Carrera con agenda justa');

  const PullCalendar(this.label);
  final String label;
}

enum PullResponse {
  favorable('Favorable'),
  plateau('Meseta'),
  interrupted('Interrupciones y cambios de material'),
  difficulty('Dificultad repetida');

  const PullResponse(this.label);
  final String label;
}

enum PullVariant {
  assisted('Dominada prona asistida'),
  australian('Dominada australiana'),
  negative('Negativa controlada'),
  singles('Dominadas pronas sueltas'),
  strict('Dominadas pronas estrictas');

  const PullVariant(this.label);
  final String label;
}

enum PullSignal { tolerated, difficulty, unknown }

enum PullDecision { calibrate, maintain, progress, reduce, test }

class PullDose {
  const PullDose(this.variant, this.setup, this.reps, this.restSeconds);

  final PullVariant variant;
  final String setup;
  final List<int> reps;
  final int restSeconds;

  String get signature =>
      '${variant.name}|$setup|${reps.join(',')}|$restSeconds';
  String get label => '${variant.label} · $setup · ${reps.join(' + ')}';
  int get minutes =>
      7 +
      ((reps.reduce((a, b) => a + b) * 6 + (reps.length - 1) * restSeconds) /
              60)
          .ceil();

  PullDose withReps(List<int> values) =>
      PullDose(variant, setup, values, restSeconds);
}

typedef PullRun = ({int day, int minutes, String name, bool quality});
typedef PullSession = ({
  int day,
  String lane,
  PullDose? dose,
  PullDecision decision,
  String reason,
  int minutes,
});
typedef _Observation = ({int day, String signature, PullSignal signal});

class PullWeek {
  const PullWeek(
    this.number,
    this.runs,
    this.sessions,
    this.unplaced,
    this.mark,
    this.note,
  );

  final int number;
  final List<PullRun> runs;
  final List<PullSession> sessions;
  final int unplaced;
  final int? mark;
  final String note;
}

/// Ensayo de decisiones. La respuesta ficticia vive aparte de la política.
List<PullWeek> simulatePullUps({
  required int? startingMark,
  required PullGear gear,
  required PullCalendar calendar,
  required PullResponse response,
  required int weeks,
}) {
  assert(weeks == 26 || weeks == 52);
  final policy = _PullPolicy(startingMark);
  final results = <PullWeek>[];
  final availability = switch (calendar) {
    PullCalendar.strength => {1: 45, 3: 45, 5: 45},
    PullCalendar.combined => {1: 50, 3: 45, 5: 50, 7: 45},
    PullCalendar.tight => {1: 32, 3: 30, 5: 18},
  };

  for (var week = 1; week <= weeks; week++) {
    final runs = _runningWeek(calendar, week);
    final currentGear =
        response == PullResponse.interrupted && week >= 13 && week <= 15
        ? PullGear.none
        : response == PullResponse.interrupted &&
              week >= 16 &&
              gear == PullGear.bands
        ? PullGear.feet
        : gear;
    final paused =
        response == PullResponse.interrupted && (week == 31 || week == 32);
    if (paused) policy.interrupt(week);
    List<PullSession> place(List<PullSession> requests) {
      final sessions = <PullSession>[];
      for (final request in requests) {
        for (final entry in availability.entries) {
          final day = entry.key;
          if (sessions.any((s) => (s.day - day).abs() < 2)) continue;
          if (policy.lastTrainingDay != null &&
              (week * 7 + day) - policy.lastTrainingDay! < 2) {
            continue;
          }
          final runsToday = runs.where((r) => r.day == day);
          if (runsToday.any((r) => r.quality) ||
              runsToday.fold<int>(
                    request.minutes,
                    (sum, r) => sum + r.minutes,
                  ) >
                  entry.value) {
            continue;
          }
          if (request.decision == PullDecision.test &&
              (runsToday.isNotEmpty ||
                  runs.any((r) => r.quality && (r.day - day).abs() < 2))) {
            continue;
          }
          sessions.add((
            day: day,
            lane: request.lane,
            dose: request.dose,
            decision: request.decision,
            reason: request.reason,
            minutes: request.minutes,
          ));
          break;
        }
      }
      return sessions..sort((a, b) => a.day.compareTo(b.day));
    }

    var requests = paused ? <PullSession>[] : policy.propose(week, currentGear);
    var sessions = place(requests);
    if (requests.any((s) => s.decision == PullDecision.test) &&
        (sessions.length < 2 ||
            !sessions.any((s) => s.decision == PullDecision.test))) {
      requests = policy.propose(week, currentGear, allowTest: false);
      sessions = place(requests);
    }
    for (final session in sessions) {
      final day = week * 7 + session.day;
      if (session.decision == PullDecision.test) {
        policy.recordMark(
          week,
          _observedMark(startingMark ?? 0, policy.completedControls, response),
        );
      } else if (session.dose case final dose?) {
        if (session.lane.isNotEmpty) {
          policy.doses[session.lane] = dose;
        }
        policy.record(
          day,
          dose,
          _response(week, response),
          calibration: session.decision == PullDecision.calibrate,
        );
      }
      policy.lastTrainingDay = day;
    }
    final unplaced = requests.length - sessions.length;
    results.add(
      PullWeek(
        week,
        runs,
        sessions,
        unplaced,
        policy.mark,
        paused
            ? 'Semana de pausa del tirón.'
            : requests.isEmpty
            ? policy.note
            : unplaced > 0
            ? 'Se aplaza trabajo de dominadas por tiempo o recuperación.'
            : '',
      ),
    );
  }
  return results;
}

List<PullRun> _runningWeek(PullCalendar calendar, int week) {
  if (calendar == PullCalendar.strength) return [];
  final tight = calendar == PullCalendar.tight;
  return [
    (
      day: tight ? 1 : 3,
      minutes: tight ? 32 : 40,
      quality: true,
      name: week.isEven ? 'Series controladas' : 'Tempo',
    ),
    (
      day: tight ? 3 : 5,
      minutes: tight ? 27 : (week % 4 == 0 ? 35 : 30),
      quality: false,
      name: 'Rodaje fácil',
    ),
  ];
}

// Guion de entrada, no una estimación a partir de entrenar. Solo se entrega
// a la política cuando realmente se puede colocar y ejecutar un control.
int _observedMark(int initial, int previousControls, PullResponse response) {
  const fromZero = [1, 2, 4, 6, 9, 12, 15, 18, 21, 23, 25];
  const fromKnown = [1, 3, 5, 8, 11, 14, 17, 20];
  final gains = switch (response) {
    PullResponse.favorable =>
      initial == 0
          ? fromZero[math.min(previousControls, fromZero.length - 1)]
          : fromKnown[math.min(previousControls, fromKnown.length - 1)],
    PullResponse.plateau => previousControls >= 2 ? 1 : 0,
    PullResponse.interrupted => (previousControls + 1) ~/ 2,
    PullResponse.difficulty => previousControls ~/ 3,
  };
  return math.min(25, initial + gains);
}

PullSignal _response(int week, PullResponse response) => switch (response) {
  PullResponse.difficulty when week % 7 <= 2 => PullSignal.difficulty,
  PullResponse.interrupted when week % 9 == 0 => PullSignal.unknown,
  PullResponse.plateau when week % 6 == 0 => PullSignal.difficulty,
  _ => PullSignal.tolerated,
};

class _PullPolicy {
  _PullPolicy(this.mark);

  int? mark;
  int? lastTrainingDay;
  int lastTest = 0;
  int completedControls = 0;
  int lastCalibration = 0;
  int lastChange = 0;
  int assistance = 3;
  PullGear? previousGear;
  bool hasCalibration = false;
  String? lastTestDose;
  String note = '';
  final evidence = <_Observation>[];
  final doses = <String, PullDose>{};

  void interrupt(int week) {
    hasCalibration = false;
    evidence.clear();
    doses.clear();
    lastCalibration = week;
  }

  void recordMark(int week, int result) {
    final resetDoses = _stage(mark) != _stage(result) || (mark ?? 0) > result;
    lastTestDose = result > (mark ?? 0) ? null : doses['volume']?.signature;
    mark = result;
    lastTest = week;
    completedControls++;
    if (resetDoses) {
      doses.clear();
      hasCalibration = false;
      lastCalibration = week;
    }
  }

  void record(
    int day,
    PullDose dose,
    PullSignal signal, {
    required bool calibration,
  }) {
    evidence.add((day: day, signature: dose.signature, signal: signal));
    if (calibration && signal == PullSignal.tolerated) hasCalibration = true;
  }

  String _setup(PullVariant variant, PullGear gear) => switch (variant) {
    PullVariant.assisted => '${gear.label}, ayuda $assistance',
    PullVariant.australian => 'Altura y pies fijos, apoyo $assistance',
    PullVariant.negative => 'Escalón, descenso de 3 s',
    _ => 'Agarre prono y recorrido completo',
  };

  int _stage(int? value) => switch (value ?? 0) {
    < 2 => 0,
    < 5 => 1,
    < 12 => 2,
    _ => 3,
  };

  List<PullSession> propose(int week, PullGear gear, {bool allowTest = true}) {
    if (previousGear != gear) {
      hasCalibration = false;
      evidence.clear();
      doses.clear();
      assistance = 3;
      previousGear = gear;
      lastCalibration = week;
    }
    if (gear == PullGear.none || ((mark ?? 0) < 2 && gear == PullGear.bar)) {
      note = 'Falta una variante accesible. Busca apoyo de pies, goma, máquina, barra baja o escalón estable.';
      return [];
    }
    final stage = _stage(mark);
    final variant = stage > 0 && gear.canTest
        ? (stage == 1 ? PullVariant.singles : PullVariant.strict)
        : gear.hasAssistance
        ? PullVariant.assisted
        : gear == PullGear.rows
        ? PullVariant.australian
        : PullVariant.negative;
    final setup = _setup(variant, gear);
    final reference = mark ?? 0;
    final startingVolume = switch (stage) {
      1 => [1, 1, 1],
      2 => List.filled(4, math.max(2, reference ~/ 2 - 1)),
      3 => List.filled(4, math.max(4, reference ~/ 2 - 2)),
      _ => variant == PullVariant.negative ? [2, 2] : [5, 5, 5],
    };
    if (!gear.canTest && stage > 0) {
      startingVolume.setAll(0, List.filled(startingVolume.length, 5));
    }
    if (!hasCalibration) {
      final dose = PullDose(variant, setup, [startingVolume.first], 120);
      return [
        _request(
          dose,
          PullDecision.calibrate,
          'Primera práctica con este montaje o vuelta tras una pausa.',
        ),
      ];
    }

    final volume =
        doses['volume'] ?? PullDose(variant, setup, startingVolume, 120);
    final comparable = _recent(volume, week);
    final top = volume.reps.every((n) => n >= 8);
    if ((variant == PullVariant.assisted ||
            variant == PullVariant.australian) &&
        top &&
        comparable == PullSignal.tolerated &&
        assistance > 1) {
      assistance--;
      doses.clear();
      evidence.clear();
      hasCalibration = false;
      lastCalibration = week;
      final trial = PullDose(variant, _setup(variant, gear), [5], 120);
      return [
        _request(
          trial,
          PullDecision.calibrate,
          variant == PullVariant.australian
              ? 'Dos días comparables en el rango alto. Probar una posición más horizontal.'
              : 'Dos días comparables en el rango alto. Probar un paso menos de ayuda.',
        ),
      ];
    }

    final sinceTest = evidence
        .where(
          (e) =>
              (e.day - 1) ~/ 7 > lastTest && e.signal == PullSignal.tolerated,
        )
        .length;
    final eligibleTest =
        allowTest &&
        gear.canTest &&
        reference < 25 &&
        week - lastTest >= 6 &&
        week - lastCalibration >= 2 &&
        sinceTest >= 4 &&
        comparable == PullSignal.tolerated &&
        volume.signature != lastTestDose &&
        (stage > 0 ||
            (variant == PullVariant.assisted && assistance == 1 && top) ||
            variant == PullVariant.negative);
    if (eligibleTest) {
      return [
        (
          day: 0,
          lane: '',
          dose: null,
          decision: PullDecision.test,
          minutes: 16,
          reason: reference == 0
              ? 'Comprobar una primera dominada prona descansada.'
              : 'Comprobar la marca tras práctica comparable.',
        ),
        _request(
          volume,
          PullDecision.maintain,
          'Conservar una exposición ordinaria esta semana.',
        ),
      ];
    }

    final first = _adapt(
      'volume',
      volume,
      week,
      ceiling: switch (variant) {
        PullVariant.assisted || PullVariant.australian => 8,
        PullVariant.negative => 3,
        PullVariant.singles => 1,
        _ => math.max(1, reference - 2),
      },
    );
    if (stage < 2 || variant != PullVariant.strict) return [first, first];

    final specific =
        doses['specific'] ??
        PullDose(
          variant,
          setup,
          stage == 3
              ? [math.max(8, reference - 5), reference ~/ 3, reference ~/ 3]
              : List.filled(3, math.max(2, reference ~/ 2)),
          150,
        );
    final second = _adapt(
      'specific',
      specific,
      week,
      ceiling: math.max(2, reference - 2),
    );
    return [first, second];
  }

  PullSignal? _recent(PullDose dose, int week) {
    final last = evidence.reversed
        .where(
          (e) => e.signature == dose.signature && (e.day - 1) ~/ 7 >= week - 4,
        )
        .take(2)
        .toList();
    if (last.length != 2 ||
        last[0].day == last[1].day ||
        last[0].signal != last[1].signal) {
      return null;
    }
    return last.first.signal;
  }

  PullSession _adapt(
    String lane,
    PullDose dose,
    int week, {
    required int ceiling,
  }) {
    final signal = _recent(dose, week);
    if (signal == PullSignal.difficulty) {
      final lower = dose.reps.map((n) => math.max(1, n - 1)).toList();
      if (lower.join(',') == dose.reps.join(',') && lower.length > 1) {
        lower.removeLast();
      }
      if (lower.join(',') == dose.reps.join(',')) {
        hasCalibration = false;
        evidence.clear();
        return _request(
          dose,
          PullDecision.calibrate,
          'La dosis mínima fue difícil. Revisar la variante o la ayuda.',
        );
      }
      final reduced = dose.withReps(lower);
      return _request(
        reduced,
        PullDecision.reduce,
        'Dos exposiciones comparables difíciles. Reducir el trabajo.',
        lane: lane,
      );
    }
    if (signal == PullSignal.tolerated &&
        lastChange != week &&
        (mark ?? 0) < 25) {
      final reps = [...dose.reps];
      final index = lane == 'specific' && _stage(mark) == 3
          ? 0
          : reps.indexOf(reps.reduce(math.min));
      if (reps[index] < ceiling) {
        reps[index]++;
        lastChange = week;
        final increased = dose.withReps(reps);
        return _request(
          increased,
          PullDecision.progress,
          'Dos días comparables tolerados. Subir una repetición en una serie.',
          lane: lane,
        );
      }
      if (dose.variant == PullVariant.singles &&
          reps.length < 5 &&
          reps.every((n) => n == 1)) {
        lastChange = week;
        return _request(
          dose.withReps([...reps, 1]),
          PullDecision.progress,
          'Añadir una repetición suelta con el mismo descanso.',
          lane: lane,
        );
      }
    }
    return _request(
      dose,
      PullDecision.maintain,
      'Mantener la dosis y registrar técnica y margen.',
      lane: lane,
    );
  }

  PullSession _request(
    PullDose dose,
    PullDecision decision,
    String reason, {
    String lane = '',
  }) => (
    day: 0,
    lane: lane,
    dose: dose,
    decision: decision,
    reason: reason,
    minutes: dose.minutes,
  );
}

import 'dart:math' as math;

enum PullGear {
  bands('Barra y gomas'),
  machine('Barra y máquina asistida'),
  feet('Barra baja con apoyo de pies'),
  rows('Barra baja solo para australianas'),
  step('Barra y escalón estable'),
  bar('Solo barra alta'),
  bandsAndRows('Barra, gomas y barra baja'),
  machineAndRows('Barra, máquina asistida y barra baja'),
  stepAndRows('Barra, escalón y barra baja'),
  none('Sin material');

  const PullGear(this.label);
  final String label;

  bool get canTest => this != rows && this != none;
  bool get hasAssistance =>
      this == bands ||
      this == bandsAndRows ||
      this == machine ||
      this == machineAndRows ||
      this == feet;
  bool get hasRows =>
      this == rows ||
      this == feet ||
      this == bandsAndRows ||
      this == machineAndRows ||
      this == stepAndRows;
}

enum PullApproach {
  current('Progresión actual del laboratorio'),
  australian('Propuesta de australianas');

  const PullApproach(this.label);
  final String label;
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
  const PullDose(
    this.variant,
    this.setup,
    this.reps,
    this.restSeconds, {
    this.widths = const [],
    this.holdSeconds = 0,
  });

  final PullVariant variant;
  final String setup;
  final List<int> reps;
  final int restSeconds;
  final List<String> widths;
  final int holdSeconds;

  bool get isCircuit => widths.isNotEmpty;

  String get signature =>
      '${variant.name}|$setup|${reps.join(',')}|$restSeconds'
      '${isCircuit ? '|${widths.join(',')}|$holdSeconds' : ''}';
  String get label => isCircuit
      ? 'Australianas supinas · $setup · '
            '${List.generate(reps.length, (i) => '${reps[i]} ${widths[i]}').join(' + ')}'
            ' + $holdSeconds s de hold cerrado'
      : '${variant.label} · $setup · ${reps.join(' + ')}';
  int get minutes => isCircuit
      // Un circuito continuo. Los cambios de ancho y el hold tienen coste propio.
      ? 3 +
            ((reps.reduce((a, b) => a + b) * 6 +
                        (reps.length - 1) * 10 +
                        holdSeconds) /
                    60)
                .ceil()
      : 7 +
            ((reps.reduce((a, b) => a + b) * 6 +
                        (reps.length - 1) * restSeconds) /
                    60)
                .ceil();

  PullDose withReps(List<int> values) => PullDose(
    variant,
    setup,
    values,
    restSeconds,
    widths: widths,
    holdSeconds: holdSeconds,
  );
}

typedef PullRun = ({int day, int minutes, String name, bool quality});

class PullSession {
  const PullSession({
    required this.day,
    required this.lane,
    required this.dose,
    required this.decision,
    required this.reason,
    required this.minutes,
    this.supportDose,
    this.supportDecision,
    this.supportReason = '',
  });

  final int day;
  final String lane;
  final PullDose? dose;
  final PullDecision decision;
  final String reason;
  final int minutes;
  final PullDose? supportDose;
  final PullDecision? supportDecision;
  final String supportReason;
}

typedef _Observation = ({int day, String signature, PullSignal signal});

class PullWeek {
  const PullWeek(
    this.number,
    this.runs,
    this.sessions,
    this.unplaced,
    this.mark,
    this.note, {
    this.deferredSupports = 0,
  });

  final int number;
  final List<PullRun> runs;
  final List<PullSession> sessions;
  final int unplaced;
  final int? mark;
  final String note;
  final int deferredSupports;
}

/// Ensayo de decisiones. La respuesta ficticia vive aparte de la política.
List<PullWeek> simulatePullUps({
  required int? startingMark,
  required PullGear gear,
  required PullCalendar calendar,
  required PullResponse response,
  required int weeks,
  PullApproach approach = PullApproach.current,
}) {
  assert(weeks == 26 || weeks == 52);
  final policy = _PullPolicy(startingMark);
  final circuits = PullCircuitPolicy();
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
              (gear == PullGear.bands || gear == PullGear.bandsAndRows)
        ? PullGear.feet
        : gear;
    final paused =
        response == PullResponse.interrupted && (week == 31 || week == 32);
    if (paused) policy.interrupt(week);
    if (paused) circuits.reset();
    circuits.useGear(currentGear);
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
          final runningMinutes = runsToday.fold<int>(
            0,
            (sum, r) => sum + r.minutes,
          );
          final includeSupport =
              request.supportDose != null &&
              request.minutes + runningMinutes <= entry.value;
          final minutes =
              request.minutes -
              (request.supportDose != null && !includeSupport
                  ? request.supportDose!.minutes + 2
                  : 0);
          if (runsToday.any((r) => r.quality) ||
              minutes + runningMinutes > entry.value) {
            continue;
          }
          if (request.decision == PullDecision.test &&
              (runsToday.isNotEmpty ||
                  runs.any((r) => r.quality && (r.day - day).abs() < 2))) {
            continue;
          }
          sessions.add(
            PullSession(
              day: day,
              lane: request.lane,
              dose: request.dose,
              decision: request.decision,
              reason: request.reason,
              minutes: minutes,
              supportDose: includeSupport ? request.supportDose : null,
              supportDecision: includeSupport ? request.supportDecision : null,
              supportReason: includeSupport
                  ? request.supportReason
                  : request.supportDose != null
                  ? 'Australianas aplazadas por tiempo. Se conserva el trabajo principal.'
                  : request.supportReason,
            ),
          );
          break;
        }
      }
      return sessions..sort((a, b) => a.day.compareTo(b.day));
    }

    List<PullSession> propose({bool allowTest = true}) {
      if (paused) return [];
      // Criterio de Javier para este ensayo. No es un umbral fisiológico validado.
      final useCircuits = (policy.mark ?? 0) < 5;
      if (approach == PullApproach.australian && !useCircuits) {
        circuits.reset();
        if (currentGear == PullGear.rows) {
          policy.note =
              'Desde cinco dominadas estrictas se retiran las australianas '
              'automáticas. Falta material para practicar el tirón vertical.';
          return [];
        }
      }
      if (approach == PullApproach.australian && currentGear == PullGear.rows) {
        return [
          circuits.propose(week, 'A'),
          if (circuits.hasCalibration) circuits.propose(week, 'B'),
        ];
      }
      final primary = policy.propose(week, currentGear, allowTest: allowTest);
      if (approach == PullApproach.current) return primary;
      var index = 0;
      return primary.map((s) {
        if (s.decision == PullDecision.test) return s;
        final support = useCircuits && currentGear.hasRows
            ? circuits.propose(week, index++ == 0 ? 'A' : 'B')
            : null;
        return PullSession(
          day: s.day,
          lane: s.lane,
          dose: s.dose,
          decision: s.decision,
          reason: s.reason,
          minutes: s.minutes + (support == null ? 0 : support.minutes + 2),
          supportDose: support?.dose,
          supportDecision: support?.decision,
          supportReason:
              support?.reason ??
              (useCircuits
                  ? 'La propuesta necesita una barra baja disponible para las australianas.'
                  : 'Australianas retiradas desde cinco estrictas. Se conserva el trabajo '
                        'vertical de referencia; las variantes avanzadas están pendientes de definir.'),
        );
      }).toList();
    }

    var requests = propose();
    var sessions = place(requests);
    if (requests.any((s) => s.decision == PullDecision.test) &&
        (sessions.length < 2 ||
            !sessions.any((s) => s.decision == PullDecision.test))) {
      requests = propose(allowTest: false);
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
        if (dose.isCircuit) {
          circuits.record(
            day,
            session.lane,
            dose,
            _response(week, response),
            calibration: session.decision == PullDecision.calibrate,
          );
        } else {
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
      }
      if (session.supportDose case final support?) {
        circuits.record(
          day,
          support.widths.length == 2 ? 'A' : 'B',
          support,
          _response(week, response),
          calibration: session.supportDecision == PullDecision.calibrate,
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
        deferredSupports:
            requests.where((s) => s.supportDose != null).length -
            sessions.where((s) => s.supportDose != null).length,
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
        PullSession(
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
  }) => PullSession(
    day: 0,
    lane: lane,
    dose: dose,
    decision: decision,
    reason: reason,
    minutes: dose.minutes,
  );
}

/// Hipótesis del laboratorio. A y B conservan dosis y observaciones propias.
/// Las cifras iniciales y las guardas son parámetros de ensayo, no dosis óptimas.
class PullCircuitPolicy {
  PullGear? _gear;
  final _doses = <String, PullDose>{};
  final _calibrated = <String>{};
  final _evidence = <_Observation>[];

  bool get hasCalibration => _calibrated.isNotEmpty;

  void reset() {
    _doses.clear();
    _calibrated.clear();
    _evidence.clear();
  }

  void useGear(PullGear gear) {
    if (_gear != gear) reset();
    _gear = gear;
  }

  PullDose _dose(String lane, List<int> reps, int holdSeconds) => PullDose(
    PullVariant.australian,
    '${_gear!.label}, altura, pies y posición del hold fijos',
    reps,
    0,
    widths: lane == 'A'
        ? const ['normales', 'cerradas']
        : const ['abiertas', 'normales', 'cerradas'],
    holdSeconds: holdSeconds,
  );

  PullSession propose(int week, String lane) {
    if (!(_gear?.hasRows ?? false)) {
      throw StateError('El circuito necesita una barra baja disponible.');
    }
    final dose =
        _doses[lane] ?? _dose(lane, List.filled(lane == 'A' ? 2 : 3, 2), 2);
    var next = dose;
    var decision = PullDecision.maintain;
    var reason = 'Repetir el circuito con el mismo montaje, técnica y margen.';
    if (!_calibrated.contains(lane)) {
      decision = PullDecision.calibrate;
      reason =
          'Calibrar el circuito $lane por separado. Elegir una inclinación '
          'que permita recorrido completo y margen.';
    }
    final recent = _evidence.reversed
        .where(
          (e) => e.signature == dose.signature && (e.day - 1) ~/ 7 >= week - 4,
        )
        .take(2)
        .toList();
    final comparable =
        recent.length == 2 &&
        recent[0].day != recent[1].day &&
        recent[0].signal == recent[1].signal;
    if (comparable && recent.first.signal == PullSignal.difficulty) {
      // Recortar una sola variable mantiene legible la respuesta del ensayo.
      final reps = [...dose.reps];
      final index = reps.indexOf(reps.reduce(math.max));
      if (reps[index] > 1) {
        reps[index]--;
        next = _dose(lane, reps, dose.holdSeconds);
        decision = PullDecision.reduce;
        reason =
            'Dos días comparables difíciles. Quitar una repetición del circuito $lane.';
      } else if (dose.holdSeconds > 1) {
        next = _dose(lane, reps, dose.holdSeconds - 1);
        decision = PullDecision.reduce;
        reason = 'Dos días comparables difíciles. Recortar un segundo de hold.';
      } else {
        decision = PullDecision.calibrate;
        reason = 'La dosis mínima sigue difícil. Revisar la inclinación antes de continuar.';
      }
    } else if (_calibrated.contains(lane) &&
        comparable &&
        recent.first.signal == PullSignal.tolerated) {
      final reps = [...dose.reps];
      final index = reps.indexOf(reps.reduce(math.min));
      if (reps[index] < 5) {
        reps[index]++;
        next = _dose(lane, reps, dose.holdSeconds);
        decision = PullDecision.progress;
        reason =
            'Dos días comparables tolerados. Añadir una repetición al circuito $lane.';
      } else if (dose.holdSeconds < 5) {
        next = _dose(lane, reps, dose.holdSeconds + 1);
        decision = PullDecision.progress;
        reason = 'Dos días comparables tolerados. Añadir un segundo de hold.';
      } else {
        reason =
            'Receta $lane alcanzada con este montaje. Mantener y revisar '
            'la inclinación mediante otra calibración.';
      }
    }
    return PullSession(
      day: 0,
      lane: lane,
      dose: next,
      decision: decision,
      reason: reason,
      minutes: next.minutes,
    );
  }

  void record(
    int day,
    String lane,
    PullDose dose,
    PullSignal signal, {
    bool calibration = false,
  }) {
    _doses[lane] = dose;
    _evidence.add((day: day, signature: dose.signature, signal: signal));
    if (calibration) _calibrated.remove(lane);
    if (signal == PullSignal.tolerated) _calibrated.add(lane);
  }
}

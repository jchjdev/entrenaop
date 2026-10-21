import 'package:workout_core/workout_template.dart';
import 'package:workout_core/running_workout_estimator.dart';

/// Valida la forma del formulario, nunca la dosis de un trabajo incompleto.
/// Los textos y ambas modalidades se conservan sin parsear ni normalizar.
class WorkoutEditorSnapshot {
  WorkoutEditorSnapshot(Map<String, dynamic> value) : value = _validate(value);
  final Map<String, dynamic> value;
  static Map<String, dynamic> _validate(Map<String, dynamic> value) {
    void require(bool condition) {
      if (!condition) {
        throw const FormatException(
          'Trabajo de sesión incompatible. Se conserva sin sobrescribir.',
        );
      }
    }

    void texts(Map row, List<String> keys) {
      for (final key in keys) {
        require(row[key] is String && (row[key] as String).length <= 10000);
      }
    }

    void shape(Map row, List<String> allowed) {
      require(row.keys.every((key) => key is String && allowed.contains(key)));
    }

    List<Map> rows(Map row, String key, int limit) {
      require(row[key] is List && (row[key] as List).length <= limit);
      return (row[key] as List).map((e) {
        require(e is Map);
        return e as Map;
      }).toList();
    }

    shape(value, [
      'schema',
      'running',
      'nameText',
      'descriptionText',
      'durationText',
      'segments',
      'blocks',
    ]);
    require(value['schema'] == 1 && value['running'] is bool);
    texts(value, ['nameText', 'descriptionText', 'durationText']);
    for (final s in rows(value, 'segments', 40)) {
      shape(s, [
        'countText',
        'targetText',
        'paceText',
        'paceMaxText',
        'recoveryTimeText',
        'byDistance',
        'recoveryByDistance',
        'recoveryType',
      ]);
      texts(s, [
        'countText',
        'targetText',
        'paceText',
        'paceMaxText',
        'recoveryTimeText',
      ]);
      require(s['byDistance'] is bool && s['recoveryByDistance'] is bool);
      require(
        s['recoveryType'] == null ||
            RunningRecoveryType.values.any((v) => v.name == s['recoveryType']),
      );
    }
    for (final b in rows(value, 'blocks', 100)) {
      shape(b, [
        'nameText',
        'roundsText',
        'restText',
        'capText',
        'format',
        'exercises',
      ]);
      texts(b, ['nameText', 'roundsText', 'restText', 'capText']);
      require(WorkoutBlockFormat.values.any((v) => v.name == b['format']));
      for (final e in rows(b, 'exercises', 100)) {
        shape(e, [
          'exerciseId',
          'targetType',
          'automaticSlot',
          'customSets',
          'countText',
          'targetText',
          'restText',
          'loadText',
          'rirText',
          'amrapRepetitionsText',
          'amrapRirText',
          'variations',
        ]);
        texts(e, [
          'countText',
          'targetText',
          'restText',
          'loadText',
          'rirText',
          'amrapRepetitionsText',
          'amrapRirText',
        ]);
        require(e['exerciseId'] == null || e['exerciseId'] is String);
        require(e['automaticSlot'] is bool && e['customSets'] is bool);
        require(WorkoutTargetType.values.any((v) => v.name == e['targetType']));
        final indices = <int>{};
        for (final v in rows(e, 'variations', 20)) {
          shape(v, [
            'setIndex',
            'targetText',
            'restText',
            'loadText',
            'rirText',
          ]);
          texts(v, ['targetText', 'restText', 'loadText', 'rirText']);
          require(
            v['setIndex'] is int &&
                (v['setIndex'] as int) >= 0 &&
                (v['setIndex'] as int) < 20 &&
                indices.add(v['setIndex'] as int),
          );
        }
      }
    }
    return value;
  }
}

CreatePersonalWorkoutInput projectWorkoutEditorSnapshot(
  WorkoutEditorSnapshot snapshot,
) {
  final running = snapshot.value['running'] as bool;
  final name = snapshot.value['nameText'] as String;
  final description = snapshot.value['descriptionText'] as String;
  final durationText = snapshot.value['durationText'] as String;
  final segments = (snapshot.value['segments'] as List).map(
    (r) => _RawSegment(r as Map),
  );
  final blockFields = (snapshot.value['blocks'] as List).map(
    (r) => _RawBlock(r as Map),
  );
  if (running) {
    final sets = <WorkoutSetDraft>[];
    for (final segment in segments) {
      final count = int.tryParse(segment.count);
      final target = segment.byDistance
          ? double.tryParse(segment.target.replaceAll(',', '.'))
          : _clock(segment.target)?.toDouble();
      final pace = segment.pace.trim().isEmpty ? null : _pace(segment.pace);
      final paceMax = segment.paceMax.trim().isEmpty
          ? pace
          : _pace(segment.paceMax);
      final recovery = segment.recovery == null
          ? null
          : segment.recoveryByDistance
          ? double.tryParse(segment.recoveryTime.replaceAll(',', '.'))
          : _clock(segment.recoveryTime)?.toDouble();
      if (count == null ||
          count < 1 ||
          count > 40 ||
          target == null ||
          target <= 0 ||
          (segment.pace.trim().isNotEmpty && pace == null) ||
          (segment.paceMax.trim().isNotEmpty &&
              (pace == null || paceMax == null)) ||
          (segment.recovery != null && (recovery == null || recovery <= 0))) {
        throw const FormatException(
          'Revisa repeticiones, objetivo, ritmo y recuperación de los tramos.',
        );
      }
      final set = WorkoutSetDraft(
        targetType: segment.byDistance
            ? WorkoutTargetType.distance
            : WorkoutTargetType.duration,
        targetValue: target,
        restAfterSeconds: 0,
        targetPaceMinSecondsPerKm: pace,
        targetPaceMaxSecondsPerKm: paceMax,
        recoveryType: segment.recovery,
        recoveryDurationSeconds: segment.recoveryByDistance
            ? null
            : recovery?.round(),
        recoveryDistanceMeters: segment.recoveryByDistance ? recovery : null,
      );
      sets.addAll(List.filled(count, set));
    }
    final estimate = estimateRunningWorkout(sets);
    return CreatePersonalWorkoutInput(
      name: name.trim(),
      description: description.trim(),
      estimatedDurationMinutes: estimate.isComplete
          ? estimate.estimatedMinutes
          : null,
      blocks: [
        WorkoutBlockDraft(
          name: 'Carrera',
          format: WorkoutBlockFormat.running,
          exercises: [
            WorkoutExerciseDraft(exerciseId: runningExerciseId, sets: sets),
          ],
        ),
      ],
    );
  }
  final blocks = <WorkoutBlockDraft>[];
  for (final block in blockFields) {
    final format = block.format;
    final usesRounds =
        format == WorkoutBlockFormat.superset ||
        format == WorkoutBlockFormat.circuit ||
        format == WorkoutBlockFormat.intervals ||
        format == WorkoutBlockFormat.emom;
    final rounds = format == WorkoutBlockFormat.tabata
        ? 8
        : usesRounds
        ? int.tryParse(block.rounds.trim())
        : 1;
    final blockRest = format == WorkoutBlockFormat.tabata
        ? 10
        : format == WorkoutBlockFormat.emom
        ? 60
        : usesRounds
        ? _clock(block.rest.trim())
        : 0;
    final cap = format == WorkoutBlockFormat.amrap ? _clock(block.cap) : null;
    if (rounds == null ||
        rounds < 1 ||
        rounds > 20 ||
        blockRest == null ||
        (format == WorkoutBlockFormat.amrap && cap == null)) {
      throw const FormatException(
        'Revisa rondas, descanso y límite del bloque.',
      );
    }

    final exercises = <WorkoutExerciseDraft>[];
    for (final item in block.exercises) {
      if (item.exerciseId == null) {
        throw const FormatException(
          'Selecciona un ejercicio en cada posición.',
        );
      }
      final type = format == WorkoutBlockFormat.tabata
          ? WorkoutTargetType.duration
          : format == WorkoutBlockFormat.amrap
          ? WorkoutTargetType.repetitions
          : item.type;
      final targetInput = item.targetFor(format);
      final rirInput = item.rirFor(format);
      final target = format == WorkoutBlockFormat.tabata
          ? 20.0
          : type == WorkoutTargetType.duration
          ? int.tryParse(targetInput.trim())?.toDouble()
          : double.tryParse(targetInput.replaceAll(',', '.'));
      final count = format == WorkoutBlockFormat.straightSets
          ? int.tryParse(item.count)
          : usesRounds
          ? rounds
          : 1;
      final rest =
          format == WorkoutBlockFormat.tabata ||
              format == WorkoutBlockFormat.amrap ||
              format == WorkoutBlockFormat.emom ||
              format == WorkoutBlockFormat.intervals
          ? 0
          : int.tryParse(item.rest.trim());
      final load =
          format == WorkoutBlockFormat.tabata || item.load.trim().isEmpty
          ? null
          : double.tryParse(item.load.replaceAll(',', '.'));
      final rir = format == WorkoutBlockFormat.tabata || rirInput.trim().isEmpty
          ? null
          : double.tryParse(rirInput.replaceAll(',', '.'));
      if (target == null ||
          target <= 0 ||
          count == null ||
          count < 1 ||
          count > 20 ||
          rest == null ||
          (format != WorkoutBlockFormat.tabata &&
              item.load.trim().isNotEmpty &&
              load == null) ||
          (format != WorkoutBlockFormat.tabata &&
              rirInput.trim().isNotEmpty &&
              rir == null)) {
        throw const FormatException(
          'Revisa las series, objetivos, descansos y cargas.',
        );
      }
      final sets = <WorkoutSetDraft>[];
      for (var setIndex = 0; setIndex < count; setIndex++) {
        // Tabata tiene dosis fija y AMRAP un objetivo común. Las excepciones
        // ocultas se conservan en el editor, pero no contaminan su receta.
        final variation =
            item.customSets &&
                format != WorkoutBlockFormat.tabata &&
                format != WorkoutBlockFormat.amrap
            ? item.variations[setIndex]
            : null;
        final targetText = variation?.target.trim() ?? '';
        final setTarget = targetText.isEmpty
            ? target
            : type == WorkoutTargetType.duration
            ? int.tryParse(targetText)?.toDouble()
            : double.tryParse(targetText.replaceAll(',', '.'));
        final restText = variation?.rest.trim() ?? '';
        final setRest =
            format != WorkoutBlockFormat.straightSets || restText.isEmpty
            ? rest
            : int.tryParse(restText);
        final loadText = variation?.load.trim() ?? '';
        final setLoad = loadText.isEmpty
            ? load
            : double.tryParse(loadText.replaceAll(',', '.'));
        final rirText = variation?.rir.trim() ?? '';
        final setRir = rirText.isEmpty
            ? rir
            : double.tryParse(rirText.replaceAll(',', '.'));
        if (setTarget == null ||
            setTarget <= 0 ||
            setRest == null ||
            (loadText.isNotEmpty && setLoad == null) ||
            (rirText.isNotEmpty && setRir == null)) {
          throw FormatException(
            'Revisa la serie ${setIndex + 1} del ejercicio.',
          );
        }
        sets.add(
          WorkoutSetDraft(
            targetType: type,
            targetValue: setTarget,
            restAfterSeconds: setRest,
            targetLoadKg: setLoad,
            targetRir: setRir,
          ),
        );
      }
      exercises.add(
        WorkoutExerciseDraft(exerciseId: item.exerciseId!, sets: sets),
      );
    }
    blocks.add(
      WorkoutBlockDraft(
        name: block.name.trim(),
        format: format,
        rounds: rounds,
        restAfterSeconds: blockRest,
        timeCapSeconds: cap,
        exercises: exercises,
      ),
    );
  }
  final duration = durationText.trim().isEmpty
      ? null
      : int.tryParse(durationText.trim());
  if (durationText.trim().isNotEmpty && duration == null) {
    throw const FormatException('La duración estimada debe estar en minutos.');
  }
  return CreatePersonalWorkoutInput(
    name: name.trim(),
    description: description.trim(),
    estimatedDurationMinutes: duration,
    blocks: blocks,
  );
}

class _RawSegment {
  _RawSegment(this.raw);
  final Map raw;
  String get count => raw['countText'] as String;
  String get target => raw['targetText'] as String;
  String get pace => raw['paceText'] as String;
  String get paceMax => raw['paceMaxText'] as String;
  String get recoveryTime => raw['recoveryTimeText'] as String;
  bool get byDistance => raw['byDistance'] as bool;
  bool get recoveryByDistance => raw['recoveryByDistance'] as bool;
  RunningRecoveryType? get recovery => raw['recoveryType'] == null
      ? null
      : RunningRecoveryType.values.byName(raw['recoveryType'] as String);
}

class _RawBlock {
  _RawBlock(this.raw);
  final Map raw;
  String get name => raw['nameText'] as String;
  String get rounds => raw['roundsText'] as String;
  String get rest => raw['restText'] as String;
  String get cap => raw['capText'] as String;
  WorkoutBlockFormat get format =>
      WorkoutBlockFormat.values.byName(raw['format'] as String);
  Iterable<_RawExercise> get exercises =>
      (raw['exercises'] as List).map((e) => _RawExercise(e as Map));
}

class _RawExercise {
  _RawExercise(this.raw);
  final Map raw;
  String? get exerciseId => raw['exerciseId'] as String?;
  WorkoutTargetType get type =>
      WorkoutTargetType.values.byName(raw['targetType'] as String);
  String get count => raw['countText'] as String;
  String get target => raw['targetText'] as String;
  String get rest => raw['restText'] as String;
  String get load => raw['loadText'] as String;
  String get rir => raw['rirText'] as String;
  String get amrapRepetitions => raw['amrapRepetitionsText'] as String;
  String get amrapRir => raw['amrapRirText'] as String;
  bool get customSets => raw['customSets'] as bool;
  Map<int, _RawVariation> get variations => {
    for (final v in raw['variations'] as List)
      v['setIndex'] as int: _RawVariation(v as Map),
  };
  String targetFor(WorkoutBlockFormat format) =>
      format == WorkoutBlockFormat.amrap &&
          type != WorkoutTargetType.repetitions
      ? amrapRepetitions
      : target;
  String rirFor(WorkoutBlockFormat format) =>
      format == WorkoutBlockFormat.amrap &&
          type != WorkoutTargetType.repetitions
      ? amrapRir
      : rir;
}

class _RawVariation {
  _RawVariation(this.raw);
  final Map raw;
  String get target => raw['targetText'] as String;
  String get rest => raw['restText'] as String;
  String get load => raw['loadText'] as String;
  String get rir => raw['rirText'] as String;
}

int? _clock(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 2) return null;
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  if (minutes == null ||
      seconds == null ||
      minutes < 0 ||
      seconds < 0 ||
      seconds > 59) {
    return null;
  }
  return minutes * 60 + seconds;
}

int? _pace(String value) {
  final trimmed = value.trim();
  if (trimmed.contains(':')) return _clock(trimmed);
  if (!RegExp(r'^\d+$').hasMatch(trimmed)) return null;
  if (trimmed.length <= 2) return int.parse(trimmed) * 60;
  final minutes = int.tryParse(trimmed.substring(0, trimmed.length - 2));
  final seconds = int.tryParse(trimmed.substring(trimmed.length - 2));
  if (minutes == null || seconds == null || seconds > 59) return null;
  return minutes * 60 + seconds;
}

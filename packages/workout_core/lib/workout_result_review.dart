import 'dart:convert';

/// Instantáneas de lectura: nunca completan ni corrigen una ejecución.
class ReviewSession {
  ReviewSession({
    required this.id,
    required this.templateId,
    required this.version,
    required this.name,
    required this.startedAt,
    required this.status,
    required List<ReviewSet> sets,
    this.amrap = const [],
    this.finalRpe,
  }) : sets = List.unmodifiable(sets);
  final String id, templateId, name, status;
  final int version;
  final DateTime startedAt;
  final num? finalRpe;
  final List<ReviewSet> sets;
  final List<ReviewAmrap> amrap;

  bool canCompare(ReviewSession older) =>
      id.isNotEmpty &&
      older.id.isNotEmpty &&
      id != older.id &&
      version > 0 &&
      templateId.isNotEmpty &&
      templateId == older.templateId &&
      version == older.version &&
      older.startedAt.isBefore(startedAt) &&
      const ['completed', 'abandoned'].contains(older.status);
}

class ReviewAmrap {
  const ReviewAmrap(
    this.block,
    this.rounds,
    this.partialItem,
    this.partialReps,
  );
  final int block, rounds, partialReps;
  final int? partialItem;
}

class ReviewHistoryPage {
  const ReviewHistoryPage(this.sessions, {this.nextCursor});
  final List<ReviewSession> sessions;
  final Object? nextCursor;
}

typedef ReviewHistoryLoader =
    Future<ReviewHistoryPage> Function(Object? cursor);

/// Lectura descriptiva de la pauta y sus registros; no puntúa el rendimiento.
/// Una medición ausente no se clasifica como diferencia ni como cumplimiento.
class ReviewExecutionSummary {
  factory ReviewExecutionSummary(ReviewSession session) {
    var total = 0, completed = 0, skipped = 0, pending = 0;
    var matching = 0,
        different = 0,
        missing = 0,
        uncertain = 0,
        withoutReference = 0;
    for (final set in session.sets) {
      if (set.format == 'amrap') continue;
      total++;
      if (set.status == 'skipped') {
        skipped++;
      } else if (set.status != 'completed') {
        pending++;
      } else {
        completed++;
        if (set.uncertain) {
          uncertain++;
        } else if (set.actual.isEmpty ||
            set.targets.keys.any(
              (key) => !set.actual.containsKey(
                key == 'paceMin' || key == 'paceMax' ? 'pace' : key,
              ),
            )) {
          missing++;
        } else if (set.targets.isEmpty) {
          withoutReference++;
        } else if (set.needsReview) {
          different++;
        } else {
          matching++;
        }
      }
    }
    final amrapResults = session.amrap.map((a) => a.block).toSet().length;
    final amrapWithoutResult = session.sets
        .where((s) => s.format == 'amrap' && s.block != null)
        .map((s) => s.block!)
        .toSet()
        .difference(session.amrap.map((a) => a.block).toSet())
        .length;
    return ReviewExecutionSummary._(
      total,
      completed,
      skipped,
      pending,
      matching,
      different,
      missing,
      uncertain,
      withoutReference,
      amrapResults,
      amrapWithoutResult,
    );
  }
  const ReviewExecutionSummary._(
    this.total,
    this.completed,
    this.skipped,
    this.pending,
    this.matching,
    this.different,
    this.missing,
    this.uncertain,
    this.withoutReference,
    this.amrapResults,
    this.amrapWithoutResult,
  );
  final int total, completed, skipped, pending;
  final int matching, different, missing, uncertain, withoutReference;
  final int amrapResults, amrapWithoutResult;
}

class ReviewSet {
  ReviewSet({
    required this.id,
    required this.block,
    required this.item,
    required this.order,
    required this.exerciseId,
    required this.exerciseName,
    required this.blockName,
    required this.format,
    required this.status,
    required Map<String, num> targets,
    required Map<String, num> actual,
    required this.context,
    this.uncertain = false,
    this.variant = '',
  }) : targets = Map.unmodifiable(targets),
       actual = Map.unmodifiable(actual);
  final String id, exerciseId, exerciseName, blockName, format, status, context;
  final int? block, item, order;
  final Map<String, num> targets, actual;
  final bool uncertain;
  final String variant;
  String? get identity =>
      block == null || item == null || order == null || exerciseId.isEmpty
      ? null
      : '$block:$item:$order:$exerciseId:$format:$variant';

  /// Ausencia de medición no equivale a cumplimiento. AMRAP conserva su
  /// resultado agregado: sus posiciones de receta no son series ejecutadas.
  bool get needsReview {
    if (format == 'amrap' || uncertain || status != 'completed') return true;
    for (final entry in targets.entries) {
      final key = entry.key;
      final value = actual[key == 'paceMin' || key == 'paceMax' ? 'pace' : key];
      if (value == null) return true;
      if (key == 'paceMin') {
        if (value < entry.value) return true;
      } else if (key == 'paceMax') {
        if (value > entry.value) return true;
      } else {
        final tolerance = format == 'running'
            ? switch (key) {
                'time' => .02,
                'distance' => .01,
                'recoveryTime' || 'recoveryDistance' => .05,
                _ => 0.0,
              }
            : 0.0;
        if ((value - entry.value).abs() > entry.value.abs() * tolerance) {
          return true;
        }
      }
    }
    return actual.isEmpty;
  }
}

class ReviewPair {
  const ReviewPair(this.current, this.previous);
  final ReviewSet current;
  final ReviewSet? previous;
  bool get changedPrescription =>
      previous != null &&
      (current.context != previous!.context ||
          !_equalMeasures(current.targets, previous!.targets));
}

List<ReviewPair> compareReviewSessions(
  ReviewSession current,
  ReviewSession older,
) {
  if (!current.canCompare(older)) return const [];
  final index = <String, List<ReviewSet>>{};
  final counts = <String, int>{};
  for (final set in older.sets) {
    if (set.identity case final key?) (index[key] ??= []).add(set);
  }
  for (final set in current.sets) {
    if (set.identity case final key?) counts[key] = (counts[key] ?? 0) + 1;
  }
  return [
    for (final set in current.sets)
      ReviewPair(
        set,
        counts[set.identity] == 1 && index[set.identity]?.length == 1
            ? index[set.identity]!.single
            : null,
      ),
  ];
}

bool _equalMeasures(Map<String, num> a, Map<String, num> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

/// Codec del contrato de resultados ya existente. Los adaptadores de cada
/// consumidor aportan estas instantáneas; el dominio no conoce Supabase.
ReviewSession reviewSessionFromJson(Map<String, dynamic> row) => ReviewSession(
  id: row['id'] as String? ?? '',
  templateId: row['template_id'] as String? ?? '',
  version: (row['template_version'] as num?)?.toInt() ?? 0,
  name: row['template_name'] as String? ?? 'Sesión',
  startedAt:
      DateTime.tryParse(row['started_at'] as String? ?? '') ?? DateTime(1970),
  status: row['status'] as String? ?? 'unknown',
  finalRpe: row['final_rpe'] as num?,
  amrap: [
    for (final result in (row['workout_amrap_results'] as List? ?? []))
      ReviewAmrap(
        (result['block_order'] as num).toInt(),
        (result['completed_rounds'] as num).toInt(),
        (result['partial_item_order'] as num?)?.toInt(),
        (result['partial_reps'] as num?)?.toInt() ?? 0,
      ),
  ],
  sets: [
    for (final set in (row['workout_execution_sets'] as List? ?? []))
      reviewSetFromJson(Map<String, dynamic>.from(set as Map)),
  ],
);

ReviewSet reviewSetFromJson(Map<String, dynamic> row) {
  final target = <String, num>{}, actual = <String, num>{};
  void put(Map<String, num> into, String key, Object? value) {
    if (value is num && value.isFinite) into[key] = value;
  }

  const fields = {
    'reps': 'reps',
    'load': 'load_kg',
    'rir': 'rir',
    'rpe': 'rpe',
    'time': 'duration_seconds',
    'distance': 'distance_meters',
    'recoveryTime': 'recovery_duration_seconds',
    'recoveryDistance': 'recovery_distance_meters',
  };
  for (final entry in fields.entries) {
    put(target, entry.key, row['target_${entry.value}']);
    put(actual, entry.key, row['actual_${entry.value}']);
  }
  put(target, 'recoveryTime', row['recovery_duration_seconds']);
  put(target, 'recoveryDistance', row['recovery_distance_meters']);
  put(target, 'paceMin', row['target_pace_min_seconds_per_km']);
  put(target, 'paceMax', row['target_pace_max_seconds_per_km']);
  if (row['result_source'] == 'device') {
    put(actual, 'time', row['observed_duration_seconds']);
    put(actual, 'recoveryTime', row['observed_recovery_duration_seconds']);
  }
  if ((actual['distance'] ?? 0) > 0 && actual['time'] != null) {
    actual['pace'] = actual['time']! * 1000 / actual['distance']!;
  }
  final prescription = row['performance_prescription'] as Map?;
  final result = row['performance_result'] as Map?;
  if (prescription != null) {
    target.clear();
    actual.clear();
    final metric = switch (prescription['measurement']) {
      'REPS' || 'LOAD_REPS' || 'REPS_IN_TIME' => 'reps',
      'DURATION' || 'TIME_FOR_DISTANCE' || 'TIME_FOR_COURSE' => 'time',
      'DISTANCE' || 'HEIGHT' => 'distance',
      'MAX_LOAD' => 'load',
      _ => 'value',
    };
    put(target, metric, prescription['target_value']);
    put(actual, metric, result?['value']);
    if (metric != 'load') {
      put(target, 'load', prescription['external_load_kg']);
      put(actual, 'load', result?['load_kg']);
    }
    put(target, 'rir', prescription['target_rir']);
    put(actual, 'rir', result?['rir']);
    put(target, 'rpe', prescription['target_rpe']);
    put(actual, 'rpe', result?['rpe']);
  }
  if (row['status'] != 'completed') actual.clear();
  return ReviewSet(
    id: row['id'] as String? ?? '',
    block: (row['block_order'] as num?)?.toInt(),
    item: (row['item_order'] as num?)?.toInt(),
    order: (row['set_order'] as num?)?.toInt(),
    exerciseId: row['exercise_id'] as String? ?? '',
    exerciseName: row['exercise_name'] as String? ?? 'Ejercicio',
    blockName: row['block_name'] as String? ?? 'Bloque',
    format: row['block_format'] as String? ?? '',
    status: row['status'] as String? ?? 'unknown',
    targets: target,
    actual: actual,
    variant: prescription == null
        ? ''
        : jsonEncode([
            for (final key in const [
              'exercise_code',
              'exercise_version',
              'protocol_key',
              'protocol_version',
              'setup_key',
              'measurement',
              'load_mode',
              'intent',
            ])
              prescription[key],
          ]),
    uncertain:
        result?['technique_valid'] == false ||
        result?['conditions_confirmed'] == false ||
        result?['tolerated'] == false ||
        result?['succeeded'] == false,
    context: jsonEncode(
      _canonical({
        'running_step': row['running_step'],
        'recovery_type': row['recovery_type'],
        'rest_after_seconds': row['rest_after_seconds'],
        'block_time_cap_seconds': row['block_time_cap_seconds'],
        'performance_prescription': prescription,
      }),
    ),
  );
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

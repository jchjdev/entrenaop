import 'editor_work_checkpoint.dart';
import 'workout_editor_snapshot.dart';

/// Agrupación de presentación. Los índices siempre apuntan a los pasos planos
/// originales: abrir o plegar no reescribe una receta ni crea bucles ocultos.
class RunningEditorGroup {
  const RunningEditorGroup(
    this.work,
    this.recovery,
    this.repetitions, {
    this.omittedAttachedRecovery = false,
  });
  final List<int> work, recovery;
  final int repetitions;
  final bool omittedAttachedRecovery;
  int get first => work.first;
  int get last => recovery.isNotEmpty && recovery.last > work.last
      ? recovery.last
      : work.last;
  bool get paired => recovery.isNotEmpty;
  bool get omitLastRecovery =>
      omittedAttachedRecovery || paired && work.length > recovery.length;
}

List<RunningEditorGroup> runningEditorGroups(
  WorkoutEditorSnapshot snapshot, {
  Set<int> separateRepetitions = const {},
  Set<int> breakBefore = const {},
}) {
  final rows = (snapshot.value['segments'] as List).cast<Map>();
  bool one(int i) => rows[i]['countText'] == '1';
  bool soft(int i) => const [
    'recovery',
    'rest',
    'walking',
    'jogging',
  ].contains(rows[i]['stepKind']);
  bool pair(int i) =>
      i + 1 < rows.length &&
      one(i) &&
      one(i + 1) &&
      const [
        null,
        'run',
        'warmup',
        'cooldown',
        'walking',
        'jogging',
      ].contains(rows[i]['stepKind']) &&
      rows[i]['recoveryType'] == null &&
      soft(i + 1) &&
      rows[i + 1]['recoveryType'] == null;
  Object comparable(Map row) => canonicalEditorState({
    ...Map<String, dynamic>.from(row),
    if (row['recoveryType'] == null) ...{
      'recoveryTimeText': '',
      'recoveryByDistance': false,
    },
  });
  bool same(int a, int b) => comparable(rows[a]) == comparable(rows[b]);
  final result = <RunningEditorGroup>[];
  var i = 0;
  while (i < rows.length) {
    final start = i;
    if (pair(i)) {
      final work = <int>[i], recovery = <int>[i + 1];
      i += 2;
      if (!separateRepetitions.contains(start)) {
        while (pair(i) &&
            !separateRepetitions.contains(i) &&
            !breakBefore.contains(i) &&
            same(start, i) &&
            same(start + 1, i + 1)) {
          work.add(i);
          recovery.add(i + 1);
          i += 2;
        }
        if (i < rows.length &&
            !separateRepetitions.contains(i) &&
            !breakBefore.contains(i) &&
            same(start, i) &&
            (i + 1 == rows.length || !soft(i + 1))) {
          work.add(i++);
        }
      }
      result.add(RunningEditorGroup(work, recovery, work.length));
    } else {
      final count = int.tryParse(rows[start]['countText'] as String);
      if (count != null &&
          count > 0 &&
          rows[start]['recoveryType'] != null &&
          i + 1 < rows.length &&
          one(i + 1) &&
          rows[i + 1]['recoveryType'] == null &&
          !separateRepetitions.contains(start) &&
          !separateRepetitions.contains(i + 1) &&
          !breakBefore.contains(i + 1) &&
          canonicalEditorState({
                ...Map<String, dynamic>.from(rows[start]),
                'countText': '1',
                'recoveryType': null,
                'recoveryTimeText': '',
                'recoveryByDistance': false,
              }) ==
              canonicalEditorState({
                ...Map<String, dynamic>.from(rows[i + 1]),
                'recoveryTimeText': '',
                'recoveryByDistance': false,
              })) {
        result.add(
          RunningEditorGroup(
            [i, i + 1],
            const [],
            count + 1,
            omittedAttachedRecovery: true,
          ),
        );
        i += 2;
        continue;
      }
      final work = <int>[i++];
      if (one(start) && !separateRepetitions.contains(start)) {
        while (i < rows.length &&
            !pair(i) &&
            one(i) &&
            !separateRepetitions.contains(i) &&
            !breakBefore.contains(i) &&
            same(start, i)) {
          work.add(i++);
        }
      }
      result.add(
        RunningEditorGroup(
          work,
          const [],
          work.length == 1
              ? int.tryParse(rows[start]['countText'] as String) ?? 1
              : work.length,
        ),
      );
    }
  }
  return result;
}

WorkoutEditorSnapshot _replace(
  WorkoutEditorSnapshot snapshot,
  List<Map<String, dynamic>> rows,
) {
  final count = rows.fold<int>(
    0,
    (n, r) => n + (int.tryParse(r['countText'] as String) ?? 1),
  );
  if (rows.isEmpty || rows.length > 40 || count > 40) {
    throw const FormatException('La carrera no puede superar 40 tramos.');
  }
  return WorkoutEditorSnapshot({...snapshot.value, 'segments': rows});
}

List<Map<String, dynamic>> _rows(WorkoutEditorSnapshot snapshot) => [
  for (final row in snapshot.value['segments'] as List)
    Map<String, dynamic>.from(row as Map),
];

WorkoutEditorSnapshot resizeRunningEditorGroup(
  WorkoutEditorSnapshot snapshot,
  RunningEditorGroup group,
  int repetitions, {
  bool omitLastRecovery = false,
}) {
  if (repetitions < 1 || repetitions > 40) {
    throw const FormatException('Indica entre 1 y 40 repeticiones.');
  }
  final rows = _rows(snapshot), next = <Map<String, dynamic>>[];
  if (group.paired) {
    for (var i = 0; i < repetitions; i++) {
      next.add({...rows[group.first], 'countText': '1'});
      if (!omitLastRecovery || i < repetitions - 1) {
        next.add({...rows[group.recovery.first], 'countText': '1'});
      }
    }
  } else if (omitLastRecovery && rows[group.first]['recoveryType'] != null) {
    if (repetitions > 1) {
      next.add({...rows[group.first], 'countText': '${repetitions - 1}'});
    }
    next.add({...rows[group.first], 'countText': '1', 'recoveryType': null});
  } else {
    next.add({...rows[group.first], 'countText': '$repetitions'});
  }
  return _replace(snapshot, [
    ...rows.take(group.first),
    ...next,
    ...rows.skip(group.last + 1),
  ]);
}

WorkoutEditorSnapshot duplicateRunningEditorGroup(
  WorkoutEditorSnapshot snapshot,
  RunningEditorGroup group,
) {
  final rows = _rows(snapshot);
  return _replace(snapshot, [
    ...rows.take(group.last + 1),
    for (final row in rows.sublist(group.first, group.last + 1)) {...row},
    ...rows.skip(group.last + 1),
  ]);
}

WorkoutEditorSnapshot moveRunningEditorGroup(
  WorkoutEditorSnapshot snapshot,
  RunningEditorGroup group,
  RunningEditorGroup neighbour,
) {
  final rows = _rows(snapshot);
  final earlier = group.first < neighbour.first ? group : neighbour;
  final later = group.first < neighbour.first ? neighbour : group;
  if (earlier.last + 1 != later.first) {
    throw const FormatException('Elige un tramo contiguo.');
  }
  return _replace(snapshot, [
    ...rows.take(earlier.first),
    ...rows.sublist(later.first, later.last + 1),
    ...rows.sublist(earlier.first, earlier.last + 1),
    ...rows.skip(later.last + 1),
  ]);
}

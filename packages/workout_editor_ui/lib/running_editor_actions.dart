import 'workout_editor_snapshot.dart';

List<Map<String, dynamic>> _segments(WorkoutEditorSnapshot snapshot) {
  if (snapshot.value['running'] != true) {
    throw const FormatException('Estas acciones solo se aplican a carrera.');
  }
  return [
    for (final row in snapshot.value['segments'] as List)
      Map<String, dynamic>.from(row as Map),
  ];
}

int _count(Map<String, dynamic> row) {
  final value = int.tryParse(row['countText'] as String);
  if (value == null || value < 1 || value > 40) {
    throw const FormatException('Completa Veces con un número entre 1 y 40.');
  }
  return value;
}

WorkoutEditorSnapshot _result(
  WorkoutEditorSnapshot snapshot,
  List<Map<String, dynamic>> rows,
) {
  if (rows.isEmpty || rows.fold<int>(0, (n, r) => n + _count(r)) > 40) {
    throw const FormatException('La carrera no puede superar 40 tramos.');
  }
  return WorkoutEditorSnapshot({...snapshot.value, 'segments': rows});
}

bool _soft(Map<String, dynamic> row) =>
    const ['recovery', 'rest', 'walking', 'jogging'].contains(row['stepKind']);

bool canOmitRunningGroupRecovery(
  WorkoutEditorSnapshot snapshot, {
  required int first,
  required int last,
}) {
  final rows = _segments(snapshot);
  if (first < 0 || last < first || last >= rows.length) return false;
  return rows[last]['recoveryType'] != null ||
      (last > first && _soft(rows[last]));
}

/// Expande la selección en orden. La receta publicada no depende de un bucle
/// oculto del editor o de un fabricante y cada paso sigue siendo editable.
WorkoutEditorSnapshot repeatRunningEditorGroup(
  WorkoutEditorSnapshot snapshot, {
  required int first,
  required int last,
  required int repetitions,
  bool omitLastRecovery = false,
}) {
  final rows = _segments(snapshot);
  if (first < 0 ||
      last < first ||
      last >= rows.length ||
      repetitions < 1 ||
      repetitions > 40) {
    throw const FormatException(
      'Revisa los tramos y las repeticiones del grupo.',
    );
  }
  final pattern = <Map<String, dynamic>>[
    for (final row in rows.sublist(first, last + 1))
      for (var i = 0; i < _count(row); i++) {...row, 'countText': '1'},
  ];
  if (omitLastRecovery &&
      !canOmitRunningGroupRecovery(snapshot, first: first, last: last)) {
    throw const FormatException('El grupo debe terminar en una recuperación.');
  }
  final expanded = <Map<String, dynamic>>[];
  // Se comprueba el límite antes de crear las copias, también con entradas
  // incompletas: repetir un grupo nunca puede borrar trabajo previo.
  final outside = [
    ...rows.take(first),
    ...rows.skip(last + 1),
  ].fold<int>(0, (n, r) => n + _count(r));
  final removesStep = omitLastRecovery && pattern.last['recoveryType'] == null;
  if (outside + pattern.length * repetitions - (removesStep ? 1 : 0) > 40) {
    throw const FormatException('La carrera no puede superar 40 tramos.');
  }
  for (var round = 0; round < repetitions; round++) {
    for (var position = 0; position < pattern.length; position++) {
      final row = Map<String, dynamic>.from(pattern[position]);
      if (omitLastRecovery &&
          round == repetitions - 1 &&
          position == pattern.length - 1) {
        if (row['recoveryType'] != null) {
          row['recoveryType'] = null;
        } else {
          continue;
        }
      }
      expanded.add(row);
    }
  }
  return _result(snapshot, [
    ...rows.take(first),
    ...expanded,
    ...rows.skip(last + 1),
  ]);
}

/// Desdobla cada pareja trabajo/recuperación, sin cambiar tiempo, distancia o
/// número de vueltas. El paso suave puede recibir después su ritmo propio.
WorkoutEditorSnapshot separateRunningEditorRecovery(
  WorkoutEditorSnapshot snapshot,
  int index,
) {
  final rows = _segments(snapshot);
  if (index < 0 ||
      index >= rows.length ||
      rows[index]['recoveryType'] == null) {
    throw const FormatException('Selecciona un tramo con recuperación.');
  }
  final row = rows[index];
  final kind = switch (row['recoveryType']) {
    'passive' => 'rest',
    'walking' => 'walking',
    'jogging' => 'recovery',
    _ => throw const FormatException('Recuperación incompatible.'),
  };
  final work = {...row, 'countText': '1', 'recoveryType': null};
  final soft = <String, dynamic>{
    ...row,
    'countText': '1',
    'stepKind': kind,
    'manual': false,
    'byDistance': row['recoveryByDistance'],
    'targetText': row['recoveryTimeText'],
    'paceText': '',
    'paceMaxText': '',
    'recoveryType': null,
    'recoveryTimeText': '01:00',
    'recoveryByDistance': false,
  };
  return _result(snapshot, [
    ...rows.take(index),
    for (var i = 0; i < _count(row); i++) ...[
      Map<String, dynamic>.from(work),
      Map<String, dynamic>.from(soft),
    ],
    ...rows.skip(index + 1),
  ]);
}

import 'package:flutter/material.dart';
import 'package:trainer_access/trainer_access.dart';

import 'trainer_workout_repository.dart';

/// Consulta sin controles de corrección: los resultados pertenecen al alumno.
class TrainerWorkoutResultPage extends StatefulWidget {
  const TrainerWorkoutResultPage({
    super.key,
    required this.repository,
    required this.assignmentId,
  });
  final TrainerWorkoutRepository repository;
  final String assignmentId;
  @override
  State<TrainerWorkoutResultPage> createState() =>
      _TrainerWorkoutResultPageState();
}

class _TrainerWorkoutResultPageState extends State<TrainerWorkoutResultPage> {
  late Future<WorkoutJson?> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.result(widget.assignmentId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Resultado del alumno'),
      actions: [
        IconButton(
          onPressed: () => setState(
            () => _future = widget.repository.result(widget.assignmentId),
          ),
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: FutureBuilder<WorkoutJson?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(trainerError(snapshot.error!)),
                  TextButton(
                    onPressed: () => setState(
                      () => _future = widget.repository.result(
                        widget.assignmentId,
                      ),
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final row = snapshot.data;
        if (row == null) {
          return const Center(
            child: Text('Todavía no hay una ejecución de esta pauta.'),
          );
        }
        return TrainerWorkoutResultContent(result: row);
      },
    ),
  );
}

class TrainerWorkoutResultContent extends StatelessWidget {
  const TrainerWorkoutResultContent({super.key, required this.result});
  final WorkoutJson result;
  @override
  Widget build(BuildContext context) {
    final sets = (result['workout_execution_sets'] as List? ?? []).cast<Map>();
    final amrap = (result['workout_amrap_results'] as List? ?? []).cast<Map>();
    final hasSeries = sets.any((set) => set['block_format'] != 'amrap');
    final status = switch (result['status']) {
      'completed' => 'Completada',
      'abandoned' => 'Abandonada',
      _ => 'En curso',
    };
    final completed = sets.where((s) => s['status'] == 'completed').length;
    final skipped = sets.where((s) => s['status'] == 'skipped').length;
    final started = DateTime.tryParse(result['started_at'] as String? ?? '');
    final abandonment = switch (result['abandonment_reason']) {
      'lack_of_time' => 'Falta de tiempo',
      'too_difficult' => 'Demasiado difícil',
      'discomfort' => 'Molestias',
      'other' => 'Otro motivo',
      _ => null,
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              result['template_name'] as String,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('$status · Versión ${result['template_version']}'),
            if (started != null)
              Text('Inicio: ${trainerDate(started.toLocal())}'),
            const SizedBox(height: 16),
            if (hasSeries)
              Text(
                '$completed ${completed == 1 ? 'serie completada' : 'series completadas'} · $skipped omitidas',
              ),
            if (result['final_rpe'] != null)
              Text('Esfuerzo final: ${result['final_rpe']}/10'),
            if (result['average_heart_rate_bpm'] != null)
              Text('Pulso medio: ${result['average_heart_rate_bpm']} lpm'),
            if (result['max_heart_rate_bpm'] != null)
              Text('Pulso máximo: ${result['max_heart_rate_bpm']} lpm'),
            if (abandonment != null) Text('Motivo: $abandonment'),
            if ((result['notes'] as String?)?.isNotEmpty == true)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sensaciones del alumno',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(result['notes'] as String),
                    ],
                  ),
                ),
              ),
            for (final block in amrap)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'AMRAP · Bloque ${(block['block_order'] as int) + 1}: ${block['completed_rounds']} rondas completas'
                    '${block['partial_item_order'] == null ? '' : ' · ejercicio ${(block['partial_item_order'] as int) + 1}: ${block['partial_reps']} rep adicionales'}',
                  ),
                ),
              ),
            for (final set in sets)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${set['block_name']} · ${set['exercise_name']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Serie ${(set['set_order'] as int) + 1} · ${set['block_format'] == 'amrap' ? 'Receta AMRAP' : _setStatus(set['status'])}',
                      ),
                      const SizedBox(height: 8),
                      Text('Pautado: ${_measures(set, 'target_')}'),
                      if (set['block_format'] != 'amrap')
                        Text(
                          'Realizado: ${set['status'] == 'completed' ? _measures(set, 'actual_') : 'Sin registro de resultado'}',
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _setStatus(dynamic status) => switch (status) {
  'completed' => 'Completada',
  'skipped' => 'Omitida',
  _ => 'Pendiente',
};
String _measures(Map row, String prefix) {
  final values = <String>[];
  for (final field in const [
    ('reps', 'rep'),
    ('distance_meters', 'm'),
    ('load_kg', 'kg'),
    ('rpe', 'RPE'),
    ('rir', 'RIR'),
  ]) {
    final value = row['$prefix${field.$1}'];
    if (value != null) values.add('$value ${field.$2}');
  }
  final duration = row['${prefix}duration_seconds'] as num?;
  if (duration != null) values.add(_time(duration.toInt()));
  final recovery =
      row['${prefix == 'target_' ? '' : prefix}recovery_duration_seconds']
          as num?;
  final recoveryDistance =
      row['${prefix == 'target_' ? '' : prefix}recovery_distance_meters'];
  if (recovery != null) values.add('recuperación ${_time(recovery.toInt())}');
  if (recoveryDistance != null) values.add('recuperación $recoveryDistance m');
  if (prefix == 'target_') {
    final pace = row['target_pace_min_seconds_per_km'] as num?;
    final max = row['target_pace_max_seconds_per_km'] as num?;
    if (pace != null) {
      values.add(
        '${_time(pace.toInt())}${max == null || max == pace ? '' : '–${_time(max.toInt())}'}/km',
      );
    }
    final rest = row['rest_after_seconds'] as num?;
    if (rest != null && rest > 0) values.add('descanso ${_time(rest.toInt())}');
  }
  return values.isEmpty ? 'Sin valores registrados' : values.join(' · ');
}

String _time(int value) =>
    '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}';
